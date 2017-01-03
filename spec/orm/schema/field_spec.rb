require 'spec_helper'

describe MassiveRecord::ORM::Schema::Field do
  describe "initializer" do
    %w(name column default allow_nil).each do |attr_name|
      it "should set #{attr_name}" do
        field = MassiveRecord::ORM::Schema::Field.new attr_name => "a_value"
        expect(field.send(attr_name)).to eq("a_value")
      end
    end

    it "should set type, cast it to a symbol" do
      expect(MassiveRecord::ORM::Schema::Field.new(:type => "a_value").type).to eq(:a_value)
    end

    it "should default to type string" do
      expect(MassiveRecord::ORM::Schema::Field.new(:name => "a_value").type).to eq(:string)
    end

    it "should default allow nil to true" do
      expect(MassiveRecord::ORM::Schema::Field.new(:name => "a_value").allow_nil).to be_true
    end
  end

  describe "new_with_arguments_from_dsl" do
    it "should take the first argument as name" do
      field = MassiveRecord::ORM::Schema::Field.new_with_arguments_from_dsl("info")
      expect(field.name).to eq("info")
    end

    it "should take the second argument as type" do
      field = MassiveRecord::ORM::Schema::Field.new_with_arguments_from_dsl("info", "integer")
      expect(field.type).to eq(:integer)
    end

    it "should take type as an option" do
      field = MassiveRecord::ORM::Schema::Field.new_with_arguments_from_dsl("info", :type => :integer)
      expect(field.type).to eq(:integer)
    end

    it "should take the rest as options" do
      field = MassiveRecord::ORM::Schema::Field.new_with_arguments_from_dsl("info", "integer", :default => 0)
      expect(field.default).to eq(0)
    end
  end

  describe "validations" do
    before do
      @fields = MassiveRecord::ORM::Schema::Fields.new
      @field = MassiveRecord::ORM::Schema::Field.new :name => "field_name", :fields => @fields
    end

    it "should be valid from before hook" do
      expect(@field).to be_valid
    end

    it "should not be valid if name is blank" do
      @field.send(:name=, nil)
      expect(@field).not_to be_valid
    end
    
    it "should not be valid without fields to belong to" do
      @field.fields = nil
      expect(@field).not_to be_valid
    end

    it "should not be valid if it's parent some how knows that it's name has been taken" do
      expect(@fields).to receive(:attribute_name_taken?).with("field_name").and_return true
      expect(@field).not_to be_valid
    end

    MassiveRecord::ORM::Schema::Field::TYPES.each do |type|
      it "should be valid with type #{type}" do
        @field.type = type
        expect(@field).to be_valid
      end
    end

    it "should not be valid with foo as type" do
      @field.type = :foo
      expect(@field).not_to be_valid
    end
  end

  it "should cast name to string" do
    field = MassiveRecord::ORM::Schema::Field.new(:name => :name)
    expect(field.name).to eq("name")
  end

  it "should compare two column families based on name" do
    field_1 = MassiveRecord::ORM::Schema::Field.new(:name => :name)
    field_2 = MassiveRecord::ORM::Schema::Field.new(:name => :name)

    expect(field_1).to eq(field_2)
    expect(field_1.eql?(field_2)).to be_true
  end

  it "should have the same hash value for two families with the same name" do
    field_1 = MassiveRecord::ORM::Schema::Field.new(:name => :name)
    field_2 = MassiveRecord::ORM::Schema::Field.new(:name => :name)

    expect(field_1.hash).to eq(field_2.hash)
  end

  describe "#decode" do
    it "should return a value if value is of correct class" do
      today = Date.today
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :created_at, :type => :date)
      @subject.decode(today) == today
    end

    it "should decode a boolean value" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :boolean)
      expect(@subject.decode("1")).to be_true
      expect(@subject.decode("0")).to be_falsey
      expect(@subject.decode("")).to be_nil
      expect(@subject.decode(nil)).to be_nil
      expect(@subject.decode("null")).to be_nil
    end

    it "should decode a string value" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :string)
      expect(@subject.decode("value")).to eq("value")
      expect(@subject.decode("")).to eq("")
      expect(@subject.decode(nil)).to be_nil
      expect(@subject.decode("frozen".freeze)).to eq "frozen"
    end

    it "should cast symbols to strings" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :string)
      expect(@subject.decode(:value)).to eq("value")
    end

    it "should decode string null correctly" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :string)
      expect(@subject.decode(@subject.coder.dump("null"))).to eq("null")
    end

    it "should decode string with value nil correctly" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :string)
      expect(@subject.decode(nil)).to eq(nil)
    end

    it "should decode an integer value" do
      old_combatibility = MassiveRecord::ORM::Base.backward_compatibility_integers_might_be_persisted_as_strings
      MassiveRecord::ORM::Base.backward_compatibility_integers_might_be_persisted_as_strings = true

      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :integer)
      expect(@subject.decode("1")).to eq(1)
      expect(@subject.decode(1)).to eq(1)
      expect(@subject.decode("")).to be_nil
      expect(@subject.decode(nil)).to be_nil

      MassiveRecord::ORM::Base.backward_compatibility_integers_might_be_persisted_as_strings = old_combatibility
    end

    it "accepts Bignum as a substitute for Fixnum" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :integer)
      bignum = 9999999999999999999999
      expect(bignum).to be_instance_of Bignum
      expect { @subject.decode(bignum) }.to_not raise_error
    end

    it "decodes an integer value is represented as a binary string" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :integer)
      expect(@subject.decode(nil)).to be_nil
      expect(@subject.decode("\x00\x00\x00\x00\x00\x00\x00\x01")).to eq 1
      expect(@subject.decode("\x00\x00\x00\x00\x00\x00\x00\x1C")).to eq 28
      expect(@subject.decode("\x00\x00\x00\x00\x00\x00\x00\x1E")).to eq 30
    end

    it "it forces encoding on the value to be BINARY if value is integer" do
      value = "\x00\x00\x00\x00\x00\x00\x00\x01"
      expect(value).to receive(:force_encoding).and_return(value)
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :integer)
      @subject.decode(value)
    end

    it "should decode an float value" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :code, :type => :float)
      expect(@subject.decode("12.345")).to eq(12.345)
      expect(@subject.decode("")).to be_nil
      expect(@subject.decode(nil)).to be_nil
    end
    
    it "should decode a date type" do
      today = Date.today
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :created_at, :type => :date)
      expect(@subject.decode(today.to_s)).to eq(today)
      expect(@subject.decode("")).to be_nil
      expect(@subject.decode(nil)).to be_nil
    end

    it "should set date to nil if date could not be parsed" do
      today = "foobar"
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :created_at, :type => :date)
      expect(@subject.decode(today)).to be_nil
    end
    
    it "should decode a time type" do
      today = Time.now
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :created_at, :type => :time)
      expect(@subject.decode(@subject.coder.dump(today)).to_i).to eq(today.to_i)
      expect(@subject.decode("")).to be_nil
      expect(@subject.decode(nil)).to be_nil
    end

    it "should decode time when value is ActiveSupport::TimeWithZone" do
      today = Time.now.in_time_zone('Europe/Stockholm')
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :created_at, :type => :time)
      expect(@subject.decode(today).to_i).to eq(today.to_i)
    end

    it "should set time to nil if date could not be parsed" do
      today = "foobar"
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :created_at, :type => :time)
      expect(@subject.decode(today)).to be_nil
    end

    it "should deserialize array" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :array)
      @subject.coder = MassiveRecord::ORM::Coders::JSON.new
      expect(@subject.decode(nil)).to eq(nil)
      expect(@subject.decode("")).to eq(nil)
      expect(@subject.decode("[]")).to eq([])
      expect(@subject.decode([1, 2].to_json)).to eq([1, 2])
    end

    it "should deserialize hash" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :hash)
      @subject.coder = MassiveRecord::ORM::Coders::JSON.new
      expect(@subject.decode(nil)).to eq(nil)
      expect(@subject.decode("")).to eq(nil)
      expect(@subject.decode("{}")).to eq({})
      expect(@subject.decode({:foo => 'bar'}.to_json)).to eq({'foo' => 'bar'})
    end

    it "should raise an argument if expecting array but getting something else" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :array)
      @subject.coder = MassiveRecord::ORM::Coders::JSON.new
      expect { @subject.decode("false") }.to raise_error MassiveRecord::ORM::SerializationTypeMismatch
    end

    it "should raise an argument if expecting hash but getting something else" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :hash)
      @subject.coder = MassiveRecord::ORM::Coders::JSON.new
      expect { @subject.decode("[]") }.to raise_error MassiveRecord::ORM::SerializationTypeMismatch
    end

    it "should not raise an argument if expecting hash getting nil" do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :hash)
      @subject.coder = MassiveRecord::ORM::Coders::JSON.new
      expect { @subject.decode("null") }.not_to raise_error
    end
  end

  describe "#encode" do
    before do
      @subject = MassiveRecord::ORM::Schema::Field.new(:name => :status)
      @subject.coder = MassiveRecord::ORM::Coders::JSON.new
    end

    it "should encode normal strings" do
      @subject.type = :string
      expect(@subject.encode("fooo")).to eq("fooo")
    end

    it "should encode string if value is null" do
      @subject.type = :string
      expect(@subject.encode("null")).to eq("null")
    end

    it "should encode string if value is nil" do
      @subject.type = :string
      expect(@subject.encode(nil)).to eq(nil)
    end

    it "should encode fixnum to fixnum" do
      @subject.type = :integer
      expect(@subject.encode(1)).to eq(1)
    end

    (MassiveRecord::ORM::Schema::Field::TYPES - [:integer, :string]).each do |type|
      it "should ask coder to dump value when type is #{type}" do
        @subject.type = type
        expect(@subject.coder).to receive(:dump)
        @subject.encode("{}")
      end
    end

    context "time_zone_aware_attributes" do
      before do
        @old_time_zone_aware_attributes = MassiveRecord::ORM::Base.time_zone_aware_attributes
        MassiveRecord::ORM::Base.time_zone_aware_attributes = true
      end

      after do
        MassiveRecord::ORM::Base.time_zone_aware_attributes = @old_time_zone_aware_attributes
      end

      it "should encode times in UTC" do
        europe_time = Time.now.in_time_zone('Europe/Stockholm')
        @subject = MassiveRecord::ORM::Schema::Field.new(:name => :created_at, :type => :time)
        expect(@subject.encode(europe_time)).to eq(subject.coder.dump(europe_time.utc))
      end
    end
  end

  describe "#unique_name" do
    before do
      @family = MassiveRecord::ORM::Schema::ColumnFamily.new :name => :info
      @field = MassiveRecord::ORM::Schema::Field.new :name => "field_name"
      @field_with_column = MassiveRecord::ORM::Schema::Field.new :name => "field_name", :column => "fn"
    end

    it "should raise an error if it has no contained_in" do
      expect { @field.unique_name }.to raise_error "Can't generate a unique name as I don't have a column family!"
    end

    it "should return correct unique name" do
      @family << @field
      expect(@field.unique_name).to eq("info:field_name")
    end
    
    it "should return a correct unique name when using column" do
      @family << @field_with_column
      expect(@field_with_column.unique_name).to eq("info:fn")
    end
  end

  describe "#column" do
    before do
      @field = MassiveRecord::ORM::Schema::Field.new :name => "field_name"
    end

    it "should default to name" do
      expect(@field.column).to eq("field_name")
    end

    it "should be overridable" do
      @field.column = "new"
      expect(@field.column).to eq("new")
    end

    it "should be returned as a string" do
      @field.column = :new
      expect(@field.column).to eq("new")
    end
  end

  it "should duplicate the default value" do
    default_array = []
    field = MassiveRecord::ORM::Schema::Field.new :name => "array", :type => :array, :default => default_array
    expect(field.default.object_id).not_to eq(default_array.object_id)
  end


  describe "default values" do
    it "should be able to set to a proc" do
      subject.type = :string
      subject.default = Proc.new { "foo" }
      expect(subject.default).to eq("foo")
    end

    context "when nil is allowed" do
      MassiveRecord::ORM::Schema::Field::TYPES_DEFAULTS_TO.each do |type, default|
        default = default.respond_to?(:call) ? default.call : default

        it "should should default to nil" do
          subject.type = type
          expect(subject.default).to eq(nil)
        end

        it "should default to set value" do
          subject.type = type
          subject.default = default
          expect(subject.default).to eq(default)
        end
      end
    end


    context "when nil is not allowed" do
      subject { MassiveRecord::ORM::Schema::Field.new(:name => :test, :allow_nil => false) }

      it { is_expected.not_to be_allow_nil }

      MassiveRecord::ORM::Schema::Field::TYPES_DEFAULTS_TO.reject { |type| type == :time }.each do |type, default|
        default = default.respond_to?(:call) ? default.call : default

        it "should default to #{default} when type is #{type}" do
          subject.type = type
          expect(subject.default).to eq(default)
        end
      end

      it "should default to Time.now when type is time" do
        subject.type = :time
        time = Time.now
        expect(Time).to receive(:now).and_return(time)
        expect(subject.default).to eq(time)
      end

      it "should be possible to override the default nil-not-allowed-value" do
        subject.type = :hash
        subject.default = {:foo => :bar}
        expect(subject.default).to eq({:foo => :bar})
      end
    end
  end



  describe "#hex_string_to_integer" do
    subject { MassiveRecord::ORM::Schema::Field.new(:name => :status, :type => :integer) }

    ((-2..2).to_a + [4611686018427387903]).each do |integer|
      it "decodes signed integer '#{integer}' correctly" do
        int_representation_in_hbase = [integer].pack('q').reverse
        expect(subject.send(:hex_string_to_integer, int_representation_in_hbase)).to eq integer
      end
    end
  end
end
