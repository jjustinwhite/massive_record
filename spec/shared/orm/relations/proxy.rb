shared_examples_for "relation proxy" do
  let(:proxy_target) { double(Object).as_null_object }
  let(:find_proxy_target_returns) { subject.represents_a_collection? ? [proxy_target] : proxy_target }

  before do
    subject.metadata = double(MassiveRecord::ORM::Relations::Metadata, :find_with => nil).as_null_object if subject.metadata.nil?
  end

  %w(proxy_owner proxy_target metadata).each do |method|
    it "should respond to #{method}" do
      is_expected.to respond_to method
    end
  end

  it "should be setting values by initializer" do
    proxy = MassiveRecord::ORM::Relations::Proxy.new(:proxy_owner => "proxy_owner", :proxy_target => proxy_target, :metadata => "metadata")
    expect(proxy.proxy_owner).to eq("proxy_owner")
    expect(proxy.proxy_target).to eq(proxy_target)
    expect(proxy.metadata).to eq("metadata")
  end

  describe "#loaded" do
    it "should be true when loaded" do
      subject.instance_variable_set :@loaded, true
      is_expected.to be_loaded
    end

    it "should be false when not loaded" do
      subject.instance_variable_set :@loaded, false
      is_expected.not_to be_loaded
    end

    it "should be loaded when loaded! is called" do
      subject.instance_variable_set :@loaded, false
      subject.loaded!
      is_expected.to be_loaded
    end
  end


  describe "#reset" do
    it "alters the loaded state" do
      subject.loaded!
      subject.reset
      if subject.metadata.embedded_in?
        is_expected.to be_loaded
      else
        is_expected.not_to be_loaded
      end
    end

    it "should reset the proxy_target" do
      subject.proxy_target = proxy_target
      subject.reset
      allow(subject).to receive(:find_proxy_target?).and_return(false)
      expect(subject.proxy_target).to be_blank
    end
  end

  describe "#reload" do
    before do
      allow(subject).to receive(:find_proxy_target)
    end

    it "should reset the proxy" do
      expect(subject).to receive(:can_find_proxy_target?).and_return false
      expect(subject).to receive :reset
      subject.reload
    end

    it "should call load_proxy_target" do
      expect(subject).to receive :load_proxy_target
      subject.reload
    end

    it "should return proxy_target if loaded successfully" do
      expect(subject).to receive(:can_find_proxy_target?).and_return true
      expect(subject).to receive(:find_proxy_target) { find_proxy_target_returns }
      expect(subject.reload).to eq(find_proxy_target_returns)
    end

    it "should return nil if loading of proxy_target failed" do
      allow(subject).to receive(:can_find_proxy_target?).and_return true
      expect(subject).to receive(:find_proxy_target).and_raise MassiveRecord::ORM::RecordNotFound
      expect(subject.reload).to be_blank
    end
  end




  describe "proxy_target" do
    it "should return the proxy_target if it is present" do
      subject.proxy_target = proxy_target
      expect(subject.proxy_target).to eq(proxy_target)
    end

    it "should be consodered loaded if a proxy_target has been set" do
      subject.proxy_target = proxy_target
      is_expected.to be_loaded
    end

    it "should not try to load proxy_target if it has been loaded" do
      subject.loaded!
      should_not_receive :find_proxy_target
      expect(subject.load_proxy_target).to be_blank
    end

    it "should try to load the proxy_target if it has not been loaded" do
      allow(subject).to receive(:can_find_proxy_target?).and_return true
      expect(subject).to receive(:find_proxy_target) { find_proxy_target_returns }
      subject.load_proxy_target
      expect(subject.proxy_target).to eq(find_proxy_target_returns)
    end

    it "should reset proxy if proxy_target's record was not found" do
      allow(subject).to receive(:can_find_proxy_target?).and_return true
      expect(subject).to receive(:find_proxy_target).and_raise MassiveRecord::ORM::RecordNotFound
      expect(subject.load_proxy_target).to be_blank
    end
  end


  describe "replace" do
    let(:old_proxy_target) { subject.represents_a_collection? ? [subject.proxy_target_class.new] : subject.proxy_target_class.new }
    let(:new_proxy_target) { subject.represents_a_collection? ? [subject.proxy_target_class.new] : subject.proxy_target_class.new }

    before do
      new_proxy_target.each { |target| allow(target).to receive(:valid?).and_return true } if new_proxy_target.is_a? Array
      old_proxy_target.each { |target| allow(target).to receive(:valid?).and_return true } if new_proxy_target.is_a? Array
      subject.proxy_target = old_proxy_target
    end

    it "should replace the old proxy_target with the new one" do
      subject.replace(new_proxy_target)
      expect(subject.proxy_target).to eq(new_proxy_target)
    end

    it "should reset the proxy if asked to replace with nil" do
      expect(subject).to receive(:reset)
      subject.replace(nil)
    end
  end

  describe "find_with" do
    let(:metadata) { MassiveRecord::ORM::Relations::Metadata.new 'person', :find_with => Proc.new { |proxy_target| Person.find("testing-123") }}
    let(:person) { Person.new }

    before do
      subject.metadata = metadata
      allow(subject).to receive(:can_find_proxy_target?).and_return(true)
    end

    it "should use metadata's find with if exists" do
      expect(Person).to receive(:find).with("testing-123").and_return(person)

      should_not_receive :find_proxy_target
      subject.load_proxy_target 
    end
  end
end
