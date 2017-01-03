require 'spec_helper'

describe "The Massive Record adapter" do
  
  it "should default to thrift" do
    expect(MassiveRecord.adapter).to eq(:thrift)
  end

end
