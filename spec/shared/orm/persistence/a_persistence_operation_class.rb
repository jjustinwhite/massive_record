shared_examples_for "a persistence operation class" do
  describe described_class do
    subject { described_class }

    describe '#included_modules' do
      subject { super().included_modules }
      it { should include MassiveRecord::ORM::Persistence::Operations }
    end
  end

  it "responds to execute" do
    subject.execute
  end
end
