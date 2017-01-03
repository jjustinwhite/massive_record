shared_examples_for "a persistence table operation class" do
  it_should_behave_like "a persistence operation class"

  describe described_class do
    subject { described_class }

    describe '#included_modules' do
      subject { super().included_modules }
      it {
      should include MassiveRecord::ORM::Persistence::Operations::TableOperationHelpers
    }
    end
  end
end
