class StepUserMailer < ApplicationMailer
  layout "mailer"
  add_template_helper ValueHelper

  def actions_for_step_user(step, alert_partial = nil)
    @show_step_actions = true
    to_email = step.user_email_address
    proposal = step.proposal

    unless step.api_token
      step.create_api_token
    end

    notification_for_subscriber(to_email, proposal, alert_partial, step)
  end

  def notification_for_subscriber(to_email, proposal, alert_partial = nil, step = nil)
    @step = step.decorate if step
    @alert_partial = alert_partial

    send_proposal_email(
      from_email: user_email_with_name(proposal.requester),
      to_email: to_email,
      proposal: proposal,
      template_name: "proposal_notification_email"
    )
  end
end
