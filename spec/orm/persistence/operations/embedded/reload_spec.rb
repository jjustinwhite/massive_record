
require 'spec_helper'

describe MassiveRecord::ORM::Persistence::Operations::Embedded::Reload do
  include SetUpHbaseConnectionBeforeAll 
  include SetTableNamesToTestTable

  let(:record) { Address.new("addresss-id", :street => "Asker", :number => 5) }
  let(:person) { Person.new "person-id", :name => "Thorbjorn", :age => "22" }
  let(:options) { {:this => 'hash', :has => 'options'} }
  
  subject { described_class.new(record, options) }

  before { record.person = person; record.save! }

  describe "generic behaviour" do
    it_should_behave_like "a persistence embedded operation class"
  end


  describe "#execute" do
    context "new record" do
      before { allow(record).to receive(:persisted?).and_return false }

      describe '#execute' do
        subject { super().execute }
        it { should be_false }
      end
    end

    context "persisted" do
      let(:inverse_proxy) { double(Object, :reload => true, :find => record) }
      let(:embedded_in_proxy) { subject.embedded_in_proxies.first }

      before do
        allow(subject).to receive(:inverse_proxy_for).and_return(inverse_proxy)
      end

      it "just returns false if no not embedded in any proxies" do
        allow(subject).to receive(:embedded_in_proxies).and_return []
        expect(subject.execute).to be_false
      end

      it "asks for inverse proxy" do
        expect(subject).to receive(:inverse_proxy_for).with(embedded_in_proxy).and_return(inverse_proxy)
        subject.execute
      end

      it "reloads inverse proxy" do
        expect(inverse_proxy).to receive :reload
        subject.execute
      end

      it "finds the record asked to be reloaded" do
        expect(inverse_proxy).to receive(:find).with(record.id).and_return record
        subject.execute
      end

      it "reinit record with found record's attributes and raw_data" do
        expect(record).to receive(:attributes).and_return('attributes' => {})
        expect(record).to receive(:raw_data).and_return('raw_data' => {})
        expect(record).to receive(:reinit_with).with({
          'attributes' => {'attributes' => {}},
          'raw_data' => {'raw_data' => {}}
        })
        subject.execute
      end
    end
  end
end
