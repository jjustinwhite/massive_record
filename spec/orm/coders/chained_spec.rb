require 'spec_helper'

describe MassiveRecord::ORM::Coders::Chained do
  describe "initialize" do
    it "should be able to assign coder to load- and dump with" do
      coders = MassiveRecord::ORM::Coders::JSON.new
      coder = MassiveRecord::ORM::Coders::Chained.new(coders)
      expect(coder.loaders).to include coders
      expect(coder.dumpers).to include coders
    end

    it "should be able to assign array of coders to load- and dump with" do
      coders = [MassiveRecord::ORM::Coders::JSON.new, MassiveRecord::ORM::Coders::YAML.new]
      coder = MassiveRecord::ORM::Coders::Chained.new(coders)
      expect(coder.loaders).to include *coders
      expect(coder.dumpers).to include *coders
    end

    it "should be possible to assign load_with explicitly" do
      coders = MassiveRecord::ORM::Coders::JSON.new
      load_with = MassiveRecord::ORM::Coders::YAML.new
      coder = MassiveRecord::ORM::Coders::Chained.new(coders, :load_with => load_with)
      expect(coder.loaders).to include load_with
      expect(coder.dumpers).to include coders
    end

    it "should be possible to assign dump_with explicitly" do
      coders = MassiveRecord::ORM::Coders::JSON.new
      dump_with = MassiveRecord::ORM::Coders::YAML.new
      coder = MassiveRecord::ORM::Coders::Chained.new(coders, :dump_with => dump_with)
      expect(coder.loaders).to include coders
      expect(coder.dumpers).to include dump_with
    end
  end



  describe "one coder in chain" do
    let(:subject) { MassiveRecord::ORM::Coders::Chained.new(MassiveRecord::ORM::Coders::JSON.new) }
    let(:code_with) { lambda { |value| ActiveSupport::JSON.encode(value) } }
    
    it_should_behave_like "an orm coder"
  end



  describe "two loaders in chain" do
    let(:subject) do
      MassiveRecord::ORM::Coders::Chained.new({
        :load_with => [MassiveRecord::ORM::Coders::JSON.new, MassiveRecord::ORM::Coders::YAML.new],
        :dump_with => MassiveRecord::ORM::Coders::YAML.new
      })
    end

    let(:code_with) { lambda { |value| YAML.dump(value) } }
    
    it_should_behave_like "an orm coder"

    it "it should try the next loader in the line if the first one fails" do
      data = {:foo => {'sdf' => "wef"}} # Will make the json encoder fail when YAML serialized
      expect(subject.load(YAML.dump(data))).to eq(data)
    end

    it "should raise ParseError if all fails" do
      expect { subject.load("{{}]") }.to raise_error MassiveRecord::ORM::Coders::ParseError
    end

    it "should raise EncodeError if all fails" do
      expect(subject.dumpers.first).to receive(:dump).and_raise(StandardError)
      expect { subject.dump("unable to dump") }.to raise_error MassiveRecord::ORM::Coders::EncodeError
    end
  end
end
