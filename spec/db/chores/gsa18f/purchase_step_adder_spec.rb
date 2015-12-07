require_relative "../../../db/chores/18f_purchase_step_adder"

describe Gsa18f::PurchaseStepAdder do
  describe "#run" do
    let(:early_date) { DateTime.new.getlocal(2015, 5, 1) }
    let(:later_date) { DateTime.new.getlocal(2015, 12, 2) }
    let!(:early_procurement_without_purchase) do
      create(:proposal, :with_approver, client_slug: "gsa18f",
                                        date_created: early_date)
    end
    let!(:early_procurement_with_purchase) do
      create(:proposal, :with_approval_and_purchase, client_slug: "gsa18f",
                                                     date_created: early_date)
    end
    let!(:later_procurement_with_purchase) do
      create(:proposal, :with_approval_and_purchase, client_slug: "gsa18f",
                                                     date_created: later_date)
    end

    it "adds a Purchase Step to Procurements lacking a Purchase Step" do
      described_class.run
      expect(early_procurement_without_purchase.individual_steps[1]).to be_a Steps::Purchase
    end

    it "does not add a Purchase Step to Procurements with an existing Purchase Step" do
      described_class.run
      expect(early_procurement_with_purchase.individual_steps.length).to eql 2
      expect(later_procurement_with_purchase.individual_steps.length).to eql 2
    end

  end

  describe "#unrun" do
    it "removes the Purchase Step from pre-December Procurements" do
      described_class.run
      expect(early_procurement_with_purchase.individual_steps.length).to eql 1
    end

    it "does not remove the Purchase Step from post-December Procurements" do
      described_class.run
      expect(later_procurement_with_purchase.individual_steps.length).to eql 2
    end
  end
end
