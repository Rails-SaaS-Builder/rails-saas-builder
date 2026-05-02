# frozen_string_literal: true

module Admin
  # Dummy-app-only admin page for poking at consume/release flows against a
  # real Organization subject. Drives the gem's public Subject API end-to-end
  # so an operator can watch counter rows update + hooks fire.
  #
  # Routes (via rsb-admin's page_action dispatch):
  #   GET  /admin/entitlements_playground[?subject_id=X]
  #   POST /admin/entitlements_playground/consume?subject_id=X&feature=K&amount=N
  #   POST /admin/entitlements_playground/release?subject_id=X&feature=K&amount=N
  #   POST /admin/entitlements_playground/reset?subject_id=X
  class EntitlementsPlaygroundController < ::RSB::Admin::AdminController
    before_action :load_subjects
    before_action :load_subject

    # GET /admin/entitlements_playground
    def index
      load_state
      @rsb_events = session.delete(:rsb_playground_events) || []
      render 'admin/entitlements_playground/show'
    end

    # POST /admin/entitlements_playground/consume
    def consume
      blocked = run_with_hook_capture do
        amount = positive_int(params[:amount], default: 1)
        @subject.consume!(params[:feature], amount: amount)
      end
      if blocked
        redirect_to_index alert: "Consume blocked on #{params[:feature]}."
      else
        redirect_to_index notice: "Consumed #{params[:amount] || 1} of #{params[:feature]}."
      end
    end

    # POST /admin/entitlements_playground/release
    def release
      blocked = run_with_hook_capture do
        amount = positive_int(params[:amount], default: 1)
        @subject.release!(params[:feature], amount: amount)
      end
      if blocked
        redirect_to_index alert: "Release blocked on #{params[:feature]}."
      else
        redirect_to_index notice: "Released #{params[:amount] || 1} of #{params[:feature]}."
      end
    end

    # POST /admin/entitlements_playground/reset
    def reset
      RSB::Entitlements::UsageCounter
        .where(subject_type: @subject.class.name, subject_id: @subject.id)
        .delete_all
      redirect_to_index notice: 'All usage counters reset.'
    end

    private

    def load_subjects
      @subjects = Organization.order(:id)
    end

    def load_subject
      id = params[:subject_id].presence || @subjects.first&.id
      @subject = id ? Organization.find_by(id: id) : nil
    end

    # Build a snapshot view of the subject's grants for rendering. Calls
    # `grant_for` per feature (which lazy-rolls the period under the hood).
    def load_state
      return unless @subject

      @active_subscription = @subject.active_subscription
      @grants =
        if @active_subscription
          plan_features_for(@active_subscription.plan_key).map do |pf|
            feature = RSB::Entitlements::Feature.find_by(key: pf.feature_key)
            {
              feature_key: pf.feature_key,
              kind: feature&.kind,
              limit: pf.limit_value,
              period: pf.period,
              enabled: pf.enabled,
              grant: @subject.grant_for(pf.feature_key),
              entitled: @subject.entitled_to?(pf.feature_key),
              remaining: @subject.remaining_for(pf.feature_key)
            }
          end
        else
          []
        end
    end

    def plan_features_for(plan_key)
      RSB::Entitlements::PlanFeature.where(plan_key: plan_key).order(:feature_key)
    end

    # Activates per-request hook capture. The boot-time tap (in
    # config/initializers/rsb_admin_pages.rb) checks
    # Thread.current[:rsb_playground_capture] and pushes formatted event
    # strings when the array is present. We collect raised errors here too
    # so the operator sees OverLimit / CannotRelease / ArgumentError surfaces
    # in the same events panel as the hooks.
    #
    # Returns true when the wrapped block raised a known "blocked" error —
    # the caller can use that to switch the flash type from notice to alert.
    # Stores the captured events in the session so the next render can show
    # them; flash is intentionally avoided so the rsb-admin flash partial
    # doesn't render the array as a banner alongside the per-row panel.
    def run_with_hook_capture
      Thread.current[:rsb_playground_capture] = []
      blocked = false
      begin
        yield
      rescue RSB::Entitlements::OverLimit => e
        Thread.current[:rsb_playground_capture] << "over_limit_raised: #{e.message}"
        blocked = true
      rescue RSB::Entitlements::CannotRelease => e
        Thread.current[:rsb_playground_capture] << "cannot_release_raised: #{e.message}"
        blocked = true
      rescue ArgumentError => e
        Thread.current[:rsb_playground_capture] << "argument_error: #{e.message}"
        blocked = true
      end
      events = Thread.current[:rsb_playground_capture]
      session[:rsb_playground_events] = events if events.any?
      blocked
    ensure
      Thread.current[:rsb_playground_capture] = nil
    end

    def positive_int(value, default:)
      n = value.to_i
      n.positive? ? n : default
    end

    def redirect_to_index(notice: nil, alert: nil)
      params_hash = { subject_id: @subject&.id }.compact
      redirect_to "/admin/entitlements_playground?#{params_hash.to_query}",
                  notice: notice, alert: alert
    end
  end
end
