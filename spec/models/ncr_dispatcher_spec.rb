describe NcrDispatcher do
  describe "#step_complete" do
    it "notifies the user for the next pending step" do
      work_order = create(:ncr_work_order, :with_approvers)
      steps = work_order.individual_steps
      step_1 = steps.first
      step_2 = steps.second
      step_1.update(status: "approved", approved_at: Time.current)
      step_2.update(status: "actionable")

      NcrDispatcher.new(work_order.proposal).step_complete(step_1)

      expect(email_recipients).to match_array([
        step_2.user.email_address
      ])
    end
  end

  describe "#on_proposal_update" do
    context "proposal needs to be re-reviewed" do
      it "notifies pending step users" do
        work_order = create(:ncr_work_order, :with_approvers)
        first_step = work_order.individual_steps.first
        allow(StepMailer).to receive(:proposal_notification).
          with(first_step).
          and_return(double(deliver_later: true))

        NcrDispatcher.new(work_order.proposal).on_proposal_update(modifier: nil, needs_review: true)

        expect(StepMailer).to have_received(:proposal_notification).with(first_step)
      end

      it "notifies requester and observers" do
        work_order = create(:ncr_work_order, :with_approvers)
        create(:observation, proposal_id: work_order.proposal.id)
        allow(ProposalMailer).to receive(:proposal_updated_needs_re_review).
          and_return(double(deliver_later: true)).
          exactly(2).times

        NcrDispatcher.new(work_order.proposal).on_proposal_update(modifier: nil, needs_review: true)

        expect(ProposalMailer).to have_received(:proposal_updated_needs_re_review).
          exactly(2).times
      end
    end

    context "proposal does not need re-review" do
      it "notifies step users" do
        work_order = create(:ncr_work_order, :with_approvers)
        first_step = work_order.individual_steps.first
        first_step.approve!
        allow(ProposalMailer).to receive(:proposal_updated_no_action_required).
          and_return(double(deliver_later: true))
        allow(ProposalMailer).to receive(:proposal_updated_no_action_required).
          with(first_step.user, work_order.proposal, nil).
          and_return(double(deliver_later: true)).
          exactly(1).times

        NcrDispatcher.new(work_order.proposal).on_proposal_update(modifier: nil, needs_review: false)

        expect(ProposalMailer).to have_received(:proposal_updated_no_action_required).
          with(first_step.user, work_order.proposal, nil)
      end

      it "notifies requester" do
        work_order = create(:ncr_work_order, :with_approvers)
        allow(ProposalMailer).to receive(:proposal_updated_no_action_required).
          and_return(double(deliver_later: true))
        allow(ProposalMailer).to receive(:proposal_updated_no_action_required).
          with(work_order.requester, work_order.proposal, nil).
          and_return(double(deliver_later: true)).
          exactly(1).times

        NcrDispatcher.new(work_order.proposal).on_proposal_update(modifier: nil, needs_review: false)

        expect(ProposalMailer).to have_received(:proposal_updated_no_action_required).
          with(work_order.requester, work_order.proposal, nil)
      end

      it "notifies observers" do
        work_order = create(:ncr_work_order, :with_approvers)
        observation = create(:observation, proposal_id: work_order.proposal.id)
        allow(ProposalMailer).to receive(:proposal_updated_no_action_required).
          and_return(double(deliver_later: true))
        allow(ProposalMailer).to receive(:proposal_updated_no_action_required).
          with(observation.user, work_order.proposal, nil).
          and_return(double(deliver_later: true)).
          exactly(1).times

        NcrDispatcher.new(work_order.proposal).on_proposal_update(modifier: nil, needs_review: false)

        expect(ProposalMailer).to have_received(:proposal_updated_no_action_required).
          with(observation.user, work_order.proposal, nil)
      end
    end

    context "proposal has pending step during update" do
      it "notifies the pending step user of update" do
        work_order = create(:ncr_work_order, :with_approvers)
        first_step = work_order.individual_steps.first
        create(:api_token, step: first_step)
        allow(ProposalMailer).to receive(:proposal_updated_while_step_pending).
          with(first_step).
          and_return(double(deliver_later: true))

        NcrDispatcher.new(work_order.proposal).on_proposal_update(modifier: nil, needs_review: false)

        expect(ProposalMailer).to have_received(:proposal_updated_while_step_pending).with(first_step)
      end
    end

    it "does not notify observer if they are the one making the update" do
      work_order =  create(:ncr_work_order, :with_approvers)
      proposal = work_order.proposal
      email = "requester@example.com"
      user = create(:user, client_slug: "ncr", email_address: email)
      proposal.add_observer(user)

      NcrDispatcher.new(proposal).on_proposal_update(modifier: proposal.observers.first, needs_review: false)

      expect(email_recipients).to_not include(email)
    end

    it "does not notify approver if they are the one making the update" do
      work_order =  create(:ncr_work_order, :with_approvers)
      proposal = work_order.proposal
      step_1 = work_order.individual_steps.first
      email = step_1.user.email_address

      NcrDispatcher.new(proposal).on_proposal_update(modifier: step_1.user, needs_review: false)

      expect(email_recipients).to_not include(email)
    end

    it "notifies requester if they are not the one making the update" do
      work_order =  create(:ncr_work_order, :with_approvers)
      proposal = work_order.proposal
      step_1 = work_order.individual_steps.first

      NcrDispatcher.new(proposal).on_proposal_update(modifier: step_1.user, needs_review: false)

      expect(email_recipients).to include(proposal.requester.email_address)
    end
  end
end
