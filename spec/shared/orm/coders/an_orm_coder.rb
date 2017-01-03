shared_examples_for "an orm coder" do
  it { should respond_to :load }
  it { should respond_to :dump }

  [1, "1", nil, ["foo"], {'foo' => 'bar', "1" => 3}, {'nested' => {'inner' => 'secret'}}].each do |value|
    it "should dump a #{value.class} correctly" do
      expect(subject.dump(value)).to eq(code_with.call(value))
    end

    it "should load a #{value.class} correctly" do
      expect(subject.load(code_with.call(value))).to eq(value)
    end
  end
end
