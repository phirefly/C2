describe StepUserMailer do
  include MailerSpecHelper

  describe "#notification_for_subscriber" do
    it "doesn't include action buttons" do
      proposal = create(:proposal, :with_approver)
      step = proposal.individual_steps.first

      mail = StepUserMailer.notification_for_subscriber("abc@example.com", proposal, nil, step)

      expect(mail.body.encoded).not_to have_link("Approve")
    end
  end

  describe "#actions_for_step_user" do
    let(:proposal) { create(:proposal, :with_approver) }
    let(:step) { proposal.individual_steps.first }
    let(:mail) { StepUserMailer.actions_for_step_user(step) }
    it_behaves_like "a proposal email"

    it "renders the receiver email" do
      proposal = create(:proposal, :with_approver)
      step = proposal.individual_steps.first

      mail = StepUserMailer.actions_for_step_user(step)

      expect(mail.to).to eq([step.user.email_address])
    end

    it "sets the sender name" do
      proposal = create(:proposal, :with_approver)
      step = proposal.individual_steps.first

      mail = StepUserMailer.actions_for_step_user(step)

      expect(sender_names(mail)).to eq([proposal.requester.full_name])
    end

    it "uses the approval URL" do
      proposal = create(:proposal, :with_approver)
      step = proposal.individual_steps.first
      token = create(:api_token, step: step)
      mail = StepUserMailer.actions_for_step_user(step)
      body = mail.body.encoded
      doc = Capybara.string(body)
      url = doc.find_link("Approve")[:href]

      approval_uri = Addressable::URI.parse(url)

      expect(approval_uri.path).to eq("/proposals/#{proposal.id}/approve")
      expect(approval_uri.query_values).to eq(
        "cch" => token.access_token,
        "version" => proposal.version.to_s
      )
    end

    it "alerts subscribers that they have been removed" do
      proposal = create(:proposal, :with_approver)
      step = proposal.individual_steps.first

      mail = StepUserMailer.actions_for_step_user(step, "removed")

      expect(mail.body.encoded).to include("You have been removed from this request.")
    end

    it "creates a new token" do
      proposal = create(:proposal, :with_approver)
      step = proposal.individual_steps.first
      expect(proposal.api_tokens).to eq([])

      Timecop.freeze(Time.zone.now) do
        StepUserMailer.actions_for_step_user(step).deliver_now
        step.reload
        expect(step.api_token.expires_at).to be_within(1.second).of(7.days.from_now(Time.zone.now))
      end
    end

    context "comments" do
      it "does not render comments when empty" do
        proposal = create(:proposal, :with_approver)
        step = proposal.individual_steps.first

        body = StepUserMailer.actions_for_step_user(step).body.encoded

        expect(proposal.comments.count).to eq 0
        expect(body).not_to include("Comments")
      end

      it "renders comments when present" do
        proposal = create(:proposal, :with_approver)
        create(:comment, proposal: proposal)
        step = proposal.individual_steps.first

        body = StepUserMailer.actions_for_step_user(step).body.encoded

        expect(body).to include("Comments")
      end
    end

    context "attachments" do
      it "does not render attachments when empty" do
        proposal = create(:proposal, :with_approver)
        step = proposal.individual_steps.first

        body = StepUserMailer.actions_for_step_user(step).body.encoded

        expect(proposal.attachments.count).to eq 0
        expect(body).not_to include("Attachments")
      end

      it "renders attachments when present" do
        proposal = create(:proposal, :with_approver)
        create(:attachment, proposal: proposal)
        step = proposal.individual_steps.first

        body = StepUserMailer.actions_for_step_user(step).body.encoded

        expect(body).to include("Attachments")
      end
    end

    context "alert templates" do
      it "defaults to no specific header" do
        proposal = create(:proposal, :with_approver)
        step = proposal.individual_steps.first

        body = StepUserMailer.actions_for_step_user(step).body.encoded

        expect(body).not_to include("updated")
        expect(body).not_to include("already approved")
      end

      it 'uses already_approved as a particular template' do
        proposal = create(:proposal, :with_approver)
        step = proposal.individual_steps.first

        body = StepUserMailer.actions_for_step_user(step, "already_approved").body.encoded

        expect(body).to include("updated")
        expect(body).to include("already approved")
      end

      it "uses updated as a particular template" do
        proposal = create(:proposal, :with_approver)
        step = proposal.individual_steps.first

        body = StepUserMailer.actions_for_step_user(step, "updated").body.encoded

        expect(body).to include("updated")
        expect(body).not_to include("already approved")
      end
    end

    describe "action buttons" do
      context "when the step requires approval" do
        it "email includes an 'Approve' button" do
          proposal = create(:proposal, :with_approver)
          step = proposal.individual_steps.first

          body = StepUserMailer.actions_for_step_user(step).body.encoded

          expect(body).to have_link("Approve")
        end
      end

      context "when the step requires purchase" do
        it "email includes a 'Mark as Purchased' button" do
          proposal = create(:proposal, :with_approval_and_purchase, client_slug: "gsa18f")
          purchase_step = proposal.individual_steps.second

          body = StepUserMailer.actions_for_step_user(purchase_step).body.encoded

          expect(body).to have_link("Mark as Purchased")
        end
      end
    end
  end
end
