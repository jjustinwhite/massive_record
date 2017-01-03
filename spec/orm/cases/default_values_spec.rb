require 'spec_helper'

describe "default values" do
  include SetUpHbaseConnectionBeforeAll 
  include SetTableNamesToTestTable

  subject do
    Person.new("id", {
      :name => "Thorbjorn",
      :age => 22,
      :points => 1
    })
  end

  context "new record" do
    describe '#dictionary' do
      subject { super().dictionary }
      it { is_expected.to eq Hash.new }
    end

    describe '#points' do
      subject { super().points }
      it { is_expected.to eq 1 }
    end

    describe '#status' do
      subject { super().status }
      it { is_expected.to eq false }
    end

    describe '#positive_as_default' do
      subject { super().positive_as_default }
      it { is_expected.to eq true }
    end

    describe '#phone_numbers' do
      subject { super().phone_numbers }
      it { is_expected.to eq [] }
    end
  end

  context "persisted record" do
    before do
      subject.dictionary = nil
      subject.points = nil
      subject.status = nil
      subject.positive_as_default = false
      subject.phone_numbers = nil
      subject.save!
      subject.reload
    end

    describe '#dictionary' do
      subject { super().dictionary }
      it { is_expected.to be_nil }
    end

    describe '#points' do
      subject { super().points }
      it { is_expected.to be_nil }
    end

    describe '#status' do
      subject { super().status }
      it { is_expected.to be_nil }
    end

    describe '#positive_as_default' do
      subject { super().positive_as_default }
      it { is_expected.to be_falsey }
    end

    describe '#phone_numbers' do
      subject { super().phone_numbers }
      it { is_expected.to eq [] }
    end
  end
end
