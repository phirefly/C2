describe Mailer do
  include MailerSpecHelper

  let(:proposal) { create(:proposal, :with_parallel_approvers) }
  let(:approval) { proposal.individual_steps.first }
  let(:approver) { approval.user }
  let(:requester) { proposal.requester }

  describe 'approval_reply_received_email' do
    let(:mail) { Mailer.approval_reply_received_email(approval) }

    before do
      approval.approve!
    end

    it_behaves_like "a proposal email"

    it 'renders the receiver email' do
      expect(mail.to).to eq([proposal.requester.email_address])
    end

    it "sets the sender name" do
      expect(sender_names(mail)).to eq([approver.full_name])
    end

    context 'comments' do
      it 'renders comments when present' do
        create(:comment, comment_text: 'My added comment', proposal: proposal)
        expect(mail.body.encoded).to include('Comments')
      end

      it 'does not render empty comments' do
        expect(mail.body.encoded).to_not include('Comments')
      end
    end

    context 'completed message' do
      it 'displays when all requests have been approved' do
        final_approval = proposal.individual_steps.last
        final_approval.proposal   # create a dirty cache
        final_approval.approve!
        mail = Mailer.approval_reply_received_email(final_approval)
        expect(mail.body.encoded).to include('Your request has been fully approved. See details below.')
      end

      it 'does not display when requests are still pending' do
        mail = Mailer.approval_reply_received_email(approval)
        expect(mail.body.encoded).to_not include('Your request has been fully approved. See details below.')
      end
    end
  end

  describe 'proposal_created_confirmation' do
    let(:mail) { Mailer.proposal_created_confirmation(proposal) }

    it_behaves_like "a proposal email"

    it 'renders the receiver email' do
      expect(mail.to).to eq([proposal.requester.email_address])
    end

    it "uses the default sender name" do
      expect(sender_names(mail)).to eq(["C2"])
    end
  end

  describe 'new_attachment_email' do
    let(:mail) { Mailer.new_attachment_email(requester.email_address, proposal) }

    it_behaves_like "a proposal email"
  end
end
