require 'spec_helper'
require 'orm/models/test_class'

describe MassiveRecord::ORM::Persistence::Operations do
  let(:options) { {:this => 'hash', :has => 'options'} }

  describe "factory method" do
    context "table record" do
      let(:record) { TestClass.new }

      [:insert, :update, :destroy, :atomic_operation, :reload].each do |method|
        describe "##{method}" do
          subject { described_class.send(method, record, options) }

          describe '#record' do
            subject { super().record }
            it { is_expected.to eq record }
          end

          describe '#klass' do
            subject { super().klass }
            it { is_expected.to eq record.class }
          end

          describe '#options' do
            subject { super().options }
            it { is_expected.to eq options }
          end

          it "is an instance of Persistence::Operations::#{method.to_s.classify}" do
            klass = "MassiveRecord::ORM::Persistence::Operations::#{method.to_s.classify}".constantize
            is_expected.to be_instance_of klass
          end

          it "is possible to suppress" do
             MassiveRecord::ORM::Persistence::Operations.suppress do
               expect(subject).to be_instance_of MassiveRecord::ORM::Persistence::Operations::Suppress
             end
          end

          it "is possible to force" do
            MassiveRecord::ORM::Persistence::Operations.suppress do
              MassiveRecord::ORM::Persistence::Operations.force do
                klass = "MassiveRecord::ORM::Persistence::Operations::#{method.to_s.classify}".constantize
                is_expected.to be_instance_of klass
              end
            end
          end
        end
      end
    end

    context "embedded record" do
      let(:record) { Address.new }

      [:insert, :update, :destroy, :reload].each do |method|
        describe "##{method}" do
          subject { described_class.send(method, record, options) }

          describe '#record' do
            subject { super().record }
            it { is_expected.to eq record }
          end

          describe '#klass' do
            subject { super().klass }
            it { is_expected.to eq record.class }
          end

          describe '#options' do
            subject { super().options }
            it { is_expected.to eq options }
          end

          it "is an instance of Persistence::Operations::#{method.to_s.classify}" do
            klass = "MassiveRecord::ORM::Persistence::Operations::Embedded::#{method.to_s.classify}".constantize
            is_expected.to be_instance_of klass
          end

          it "is possible to suppress" do
             MassiveRecord::ORM::Persistence::Operations.suppress do
               expect(subject).to be_instance_of MassiveRecord::ORM::Persistence::Operations::Suppress
             end
          end

          it "is possible to force" do
            MassiveRecord::ORM::Persistence::Operations.suppress do
              MassiveRecord::ORM::Persistence::Operations.force do
                klass = "MassiveRecord::ORM::Persistence::Operations::Embedded::#{method.to_s.classify}".constantize
                is_expected.to be_instance_of klass
              end
            end
          end
        end
      end
    end
  end
end
