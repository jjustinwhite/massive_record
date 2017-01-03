# Massive Record

Massive Record is a Ruby client for HBase. It provides a basic API through Thrift and an ORM with advanced features.

See introduction to HBase model architecture:  
http://wiki.apache.org/hadoop/Hbase/HbaseArchitecture  
Understanding terminology of Table / Row / Column family / Column / Cell:  
http://jimbojw.com/wiki/index.php?title=Understanding_Hbase_and_BigTable

## HBase requirement

For using it locally, you can use docker. This will use [dajobe/hbase](github.com/dajobe/hbase-docker/)
 , which will run hbase. You can use it to run the specs, for instance.

```shell
./start_hbase.sh
```

### Old instructions
MassiveRecord is tested with Hortonworks Sandbox:
http://hortonworks.com/products/sandbox

Currently, MassiveRecord is tested against HBase 1.1.4 which is pre-installed in the sandbox.

    1. Download the Sandbox (VirtualBox Image)
    2. Follow the steps to create a user
    3. Start HBase through the Ambari interface, log in through http://localhost:8080
    4. Start Thrift: /usr/bin/hbase thrift start


## Installation


First of all: Please make sure you are using Ruby 1.9.2. For now, we are only ensuring
that Massive Record works on that Ruby version, and we know it has some problems with 1.8.7.

    gem install massive_record

### Ruby on Rails
    
MassiveRecord is compatible with Rails 3.0. It is not yet fully compatible with 3.1 or any higher versions.
Add the following Gems in your Gemfile:
    
    gem 'massive_record'

Create an config/hbase.yml file with the following content:
  
    defaults: &defaults
      host: somewhere.compute.amazonaws.com # No 'http', it's a Thrift connection
      port: 9090

    development:
      <<: *defaults

    test:
      <<: *defaults

    production:
      <<: *defaults


## Usage

There are two ways for using the Massive Record library. At the highest level we have ORM. This is Active Model compliant and makes it easy to use. The second way of doing things is working directly against the adapter (simple API).


### ORM
    
Both MassiveRecord::ORM::Table and MassiveRecord::ORM::Embedded do now have some functionality which you can expect from an ORM. This includes:

- An initializer which takes attribute hash and assigns them to your object.
- Write and read methods for the attributes
- Validations, as you expect from an ActiveRecord.
- Callbacks, as you expect from an ActiveRecord.
- Information about changes on attributes.
- Casting of attributes
- Serialization of array / hashes
- Timestamps like created_at and updated_at. Updated at will always be available, created_at must be defined. See example down:
- Finder scopes. Like: Person.select(:only_columns_from_this_family).limit(10).collect(&:name)
- Ability to set a default scope.
- Time zone aware time attributes.
- Basic instrumentation and logging of query times.
- Attribute mass assignment security.

Tables also have:

- Persistencey method calls like create, save and destroy (but they do not actually save things to hbase)
- Easy access to adapter's connection via Person.connection
- Easy access to adapter's hbase table via Person.table
- Finder method, like Person.find("an_id"), Person.find("id1", "id2"), Person.all etc
- Save / update methods
- Auto-creation of table and column families on save if table does not exists.
- Destroy records
- Relations: Both references to other tables and simple embedded records. See MassiveRecord::ORM::Relations::Interface ClassMethods for documentation
- Observable. See MassiveRecord::ORM::Observer. If you know how to use ActiveRecord's observer you know how to use this one.
- IdentityMap (when enabled)


Here are some examples setting up models:

    class Person < MassiveRecord::ORM::Table
      references_one :boss, :class_name => "Person", :store_in => :info
      references_one :attachment, :polymorphic => true
      references_many :friends, :store_in => :info
      references_many :blog_posts, :records_starts_from => :posts_start_id

      embeds_many :addresses

      default_scope select(:info)

      column_family :info do
        field :name
        field :email
        field :phone_number
        field :points, :integer, :default => 0
        field :date_of_birth, :date, :allow_nil => false # Defaults to today
        field :newsletter, :boolean, :default => false
        field :type # Used for single table inheritance
        field :in_the_future, :time, :default => Proc.new { 2.hours.from_now }
        field :hobbies, :array, :allow_nil => false # Default to empty array

        timestamps # ..or field :created_at, :time
      end

      column_family :misc do
        field :with_a_lot_of_uninteresting_data
      end

      attr_accessible :name, :email, :phone_number, :date_of_birth

      validates_presence_of :name, :email
      validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i

      # Returns the id the scanner should start from in the BlogPost table
      # to fetch blog posts related to this person
      def posts_start_id
        id+'-'
      end
    end

    class Friend < Person
      # This one will be stored in Person's table with it's type set to Friend.
      # Calling Person.all will return object back as a Friend.
    end

    class PersonObserver < MassiveRecord::ORM::Observer
      def after_create(person_created)
        # Do something smart with that person
      end
    end

    class Address < MassiveRecord::ORM::Embedded
      embedded_in :person

      field :street
      field :number, :integer
      field :nice_place, :boolean, :default => true
    end
    
    class BlogPost < MassiveRecord::ORM::Embedded
      references_one :author, :class_name => "Person", :store_in => :info
    
      field :title
      field :content
      
      private
      
      # Set yourself an ID to your model
      def default_id
        "#{author_id}|#{Time.now.strftime("%Y-%m-%d-%k-%M")}"
      end
    end

Perform requests:

    # Fetch an object
    u = User.find("45")
    
    # Blog posts associated
    u.blog_posts
    
    # Blog posts associated during May 2011
    u.blog_posts(:starts_with => "45-2011-05") # user_id - year - month
    
    # Blog posts from May 2011
    u.blog_posts(:offset => "45-2011-05")
    
    # Only five blog posts
    u.blog_posts(:limit => 5)

You can find a small example application here: https://github.com/thhermansen/massive_record_test_app

### Related gems

We have developed some gems which adds support for MassiveRecord. These are:

#### ORM Adapter
https://github.com/CompanyBook/orm_adapter
Used by Devise. I guess we'll might release the code used to get Devise support in MR.

#### Database Cleaner
https://github.com/CompanyBook/database_cleaner
User by for instance Cucumber and ourself with Rspec.

#### Sunspot Rails
https://github.com/CompanyBook/sunspot_massive_record
Makes it easier to make things searchable with solr.


## Wrapper (adapter) API

You can, if you'd like, work directly against the adapter.
It is however adviced to use the ORM as the interface to the adapter is not yet very well defined.
  
    # Init a new connection with HBase
    conn = MassiveRecord::Wrapper::Connection.new(:host => 'localhost', :port => 9090)
    conn.open
    
    # OR init a connection using the config/hbase.yml file with Rails
    conn = MassiveRecord::Wrapper::Base.connection
  
    # Fetch tables name
    conn.tables # => ["companies", "news", "webpages"]
  
    # Init a table
    table = MassiveRecord::Wrapper::Table.new(conn, :people)
  
    # Add a column family
    column = MassiveRecord::Wrapper::ColumnFamily.new(:info)
    table.column_families.push(column)
  
    # Or bulk add column families
    table.create_column_families([:friends, :misc])
    
    # Create the table
    table.save # will raise an exception if the table already exists
  
    # Fetch column families from the database
    table.fetch_column_families # => [ColumnFamily#RTY4424, ColumnFamily#R475424, ColumnFamily#GHJ9424]
    table.column_families.collect(&:name) # => ["info", "friends", "misc"]
  
    # Add a new row
    row = MassiveRecord::Wrapper::Row.new
    row.id = "my_unique_id"
    row.values = { :info => { :first_name => "H", :last_name => "Base", :email => "h@base.com" } }
    row.table = table
    row.save
  
    # Fetch rows
    table.first # => MassiveRecord#ID1
    table.all(:limit => 10) # => [MassiveRecord#ID1, MassiveRecord#ID2, ...]
    table.find("ID2") # => MassiveRecord#ID2
    table.find(["ID1", "ID2"]) # => [MassiveRecord#ID1, MassiveRecord#ID2]
    table.all(:limit => 3, :starts_with => "ID2") # => [MassiveRecord#ID2, MassiveRecord#ID3, MassiveRecord#ID4]
    
    # Manipulate rows
    table.first.destroy # => true
    
    # Remove the table
    table.destroy


## Planned work

- Cache the decoded values of attributes, not use the value_is_already_decoded?. This will fix possible problem with YAML as coder backend.
- Implement other Adapters, for instance using jruby and the Java API.


## Contribute

If you want to contribute feel free to fork this project :-)
Make a feature branch, write test, implement and make a pull request.


### Getting started

    git clone git://github.com/CompanyBook/massive_record.git (or the address to your fork)
    cd massive_record
    bundle install

Next up you need to add a config.yml file inside of spec/ which contains something like:
    host: url.to-a.thrift.server
    port: 9090
    table: massive_record_test_table

You should now be able to run `rspec spec/`

### Play with it in the console

Checkout the massive_record project and install it as a Gem :

    cd massive_record/
    bundle console
    ruby-1.9.2-p0 > Bundler.require
     => [
          <Bundler::Dependency type=:runtime name="massive_record" requirements=">= 0">,
          <Bundler::Dependency type=:runtime name="thrift" requirements=">= 0.5.0">,
          <Bundler::Dependency type=:runtime name="activesupport" requirements=">= 0">,
          <Bundler::Dependency type=:runtime name="activemodel" requirements=">= 0">,
          <Bundler::Dependency type=:runtime name="rspec" requirements=">= 2.1.0">
        ]
    ruby-1.9.2-p0 > MassiveRecord::VERSION
     => "0.0.1" 
    
### Clean HBase database between each test

We have created a helper module MassiveRecord::Rspec::SimpleDatabaseCleaner which, when included into rspec tests, will clean
the database for ORM records between each test case. You can also take a look into spec/support/mock_massive_record_connection.rb
for some functionality which will mock a hbase connection making it easier (faster) to test code where no real database is needed.


## More Information and Resources

### Thrift API

Ruby Library using the HBase Thrift API.
http://wiki.apache.org/hadoop/Hbase/ThriftApi

The generated Ruby files can be found under lib/massive_record/thrift/  
The whole API (CRUD and more) is present in the Client object (Apache::Hadoop::Hbase::Thrift::Hbase::Client).  
The client can be easily initialized using the MassiveRecord connection :

    conn = MassiveRecord::Wrapper::Connection.new(:host => '127.0.0.1', :port => 9090)
    conn.open
    
    client = conn.client
    # Do whatever you want with the client object
    
### Q&A

How to add a new column family to an existing table?
    
    # Connect to the HBase console on the server itself and enter the following code :
    disable 'companies'
    alter 'companies', { NAME => 'new_collumn_familiy' }
    enable 'companies'
## Failing stuff on migrating

Just work in progress
```
Finished in 1753.92 seconds
1775 examples, 50 failures

rspec ./spec/adapter/thrift/table_spec.rb:157 # A table created with a saved row should encode everything to UTF-8
rspec ./spec/orm/cases/base_spec.rb:132 # MassiveRecord::ORM::Base equality should evaluate one object the same as equal
rspec ./spec/orm/cases/base_spec.rb:137 # MassiveRecord::ORM::Base equality should evaluate two objects of same class and id as ==
rspec ./spec/orm/cases/base_spec.rb:141 # MassiveRecord::ORM::Base equality should evaluate two objects of same class and id as eql?
rspec ./spec/orm/cases/base_spec.rb:145 # MassiveRecord::ORM::Base equality should not be equal if ids are different
rspec ./spec/orm/cases/base_spec.rb:149 # MassiveRecord::ORM::Base equality should not be equal if class are different
rspec ./spec/orm/cases/base_spec.rb:155 # MassiveRecord::ORM::Base intersection and union operation should correctly find intersection two sets
rspec ./spec/orm/cases/base_spec.rb:159 # MassiveRecord::ORM::Base intersection and union operation should correctly find union of two sets
rspec ./spec/orm/cases/base_spec.rb:163 # MassiveRecord::ORM::Base intersection and union operation should correctly find intersection between two sets with different classes
rspec ./spec/orm/cases/base_spec.rb:167 # MassiveRecord::ORM::Base intersection and union operation should correctly find union between two sets with different classes
rspec ./spec/orm/cases/encoding_spec.rb:45 # encoding without ORM should return string as UTF-8 encoded strings
rspec ./spec/orm/cases/finders_spec.rb:179 # finders#find database test should raise record not found error if table does not exist
rspec ./spec/orm/cases/finders_spec.rb:184 # finders#find database test should return the person object when found
rspec ./spec/orm/cases/finders_spec.rb:190 # finders#find database test should maintain encoding of ids
rspec ./spec/orm/cases/finders_spec.rb:196 # finders#find database test should find first person
rspec ./spec/orm/cases/finders_spec.rb:200 # finders#find database test should find all
rspec ./spec/orm/cases/finders_spec.rb:206 # finders#find database test should find all persons, even if it is more than 10
rspec ./spec/orm/cases/finders_spec.rb:211 # finders#find database test should raise error if not all requested records was found
rspec ./spec/orm/cases/finders_spec.rb:215 # finders#find database test should return what it finds if asked to
rspec ./spec/orm/cases/finders_spec.rb:229 # finders#find database test embedded records is able to load embeds many relations
rspec ./spec/orm/cases/finders_spec.rb:238 # finders#find_in_batches should iterate through a collection of group of rows using a batch process
rspec ./spec/orm/cases/finders_spec.rb:264 # finders#find_in_batches should iterate through a collection of rows using a batch process
rspec ./spec/orm/cases/finders_spec.rb:277 # finders#exists? should return true if a row exists with given id
rspec ./spec/orm/cases/persistence_spec.rb:88 # persistence#reload should reload the raw data
rspec ./spec/orm/cases/persistence_spec.rb:95 # persistence#reload should not be considered changed after reload
rspec ./spec/orm/cases/persistence_spec.rb:102 # persistence#reload should return self
rspec ./spec/orm/cases/persistence_spec.rb:106 # persistence#reload should not do anything on reload when record is not persisted
rspec ./spec/orm/cases/persistence_spec.rb:202 # persistence save database test create when table does not exists should create the table
rspec ./spec/orm/cases/persistence_spec.rb:275 # persistence save database test update should not ask for row for record when no changes have been made (update is done through this object)
rspec ./spec/orm/cases/persistence_spec.rb:280 # persistence save database test update should only include changed attributes
rspec ./spec/orm/cases/persistence_spec.rb:290 # persistence save database test update should include changed attributes for embedded objects
rspec ./spec/orm/cases/persistence_spec.rb:309 # persistence save database test update should persist the changes
rspec ./spec/orm/cases/persistence_spec.rb:316 # persistence save database test update persists changes in embedded documents
rspec ./spec/orm/cases/persistence_spec.rb:329 # persistence save database test update should not have any changes after save
rspec ./spec/orm/cases/persistence_spec.rb:335 # persistence save database test update has no changes after an embedded object is added and saved
rspec ./spec/orm/cases/persistence_spec.rb:341 # persistence save database test update should raise error if column familiy needed does not exist
rspec ./spec/orm/cases/time_zone_awareness_spec.rb:77 # Time zone awareness conversion on attribute should return time as TimeWithZone when attribute accessed directly
rspec ./spec/orm/cases/time_zone_awareness_spec.rb:84 # Time zone awareness conversion on attribute should return time as TimeWithZone when attribute accessed through read_attribute
rspec ./spec/orm/cases/time_zone_awareness_spec.rb:91 # Time zone awareness conversion on attribute should return time in local time
rspec ./spec/orm/cases/time_zone_awareness_spec.rb:112 # Time zone awareness conversion on attribute should return correct times after save
rspec ./spec/orm/cases/time_zone_awareness_spec.rb:129 # Time zone awareness conversion on attribute should store time in DB format
rspec ./spec/orm/cases/time_zone_awareness_spec.rb:146 # Time zone awareness conversion on attribute should store time in DB format, raw check
rspec ./spec/orm/cases/time_zone_awareness_spec.rb:158 # Time zone awareness conversion on attribute write string representation pf time it writes string in current time zone
rspec ./spec/orm/cases/time_zone_awareness_spec.rb:174 # Time zone awareness conversion on attribute write string representation pf time write_attribute writes in current time zone
rspec ./spec/orm/relations/proxy/references_many_spec.rb:299 # TestReferencesManyProxy adding records to collection by #<< should not update array of foreign keys in proxy_owner if it does not respond to it
rspec ./spec/orm/relations/proxy/references_many_spec.rb:299 # TestReferencesManyProxy adding records to collection by #push should not update array of foreign keys in proxy_owner if it does not respond to it
rspec ./spec/orm/relations/proxy/references_many_spec.rb:299 # TestReferencesManyProxy adding records to collection by #concat should not update array of foreign keys in proxy_owner if it does not respond to it
rspec ./spec/orm/relations/proxy/references_many_spec.rb:382 # TestReferencesManyProxy removing records from the collection with #destroy should not remove foreign keys in proxy_owner if it does not respond to it
rspec ./spec/orm/relations/proxy/references_many_spec.rb:382 # TestReferencesManyProxy removing records from the collection with #delete should not remove foreign keys in proxy_owner if it does not respond to it
rspec ./spec/thrift/cases/encoding_spec.rb:36 # encoding should save UTF8 caracteres
```

Copyright (c) 2011 Companybook, released under the MIT license
