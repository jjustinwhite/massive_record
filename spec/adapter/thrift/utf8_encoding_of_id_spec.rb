# encoding: utf-8
require 'spec_helper'

describe MassiveRecord::Wrapper::Row do
  let(:connection) do
    MassiveRecord::Wrapper::Connection.new(:host => MR_CONFIG['host'], :port => MR_CONFIG['port']).tap do |connection|
      connection.open
    end
  end

  let(:table) do
    MassiveRecord::Wrapper::Table.new(connection, MR_CONFIG['table']).tap do |table|
      table.column_families.create(:misc)
      table.save
    end
  end

  let(:id) { 'thorbjørn' }
  let(:name) { 'Thorbjorn' }

  subject do
    MassiveRecord::Wrapper::Row.new.tap do |row|
      row.id = id
      row.values = { :misc => { :name => name } }
      row.table = table
    end
  end

  after do
    table.all.each(&:destroy)
  end

  after :all do
    table.destroy
    connection.close
  end

  describe "ids utf-8 encoded" do
    context "new record" do
      it "saves" do
        expect(subject.save).to be_true
      end
    end

    context "persisted record" do
      before { subject.save }

      it "finds" do
        expect(table.find(id).values["misc:name"]).to eq name
      end

      it "gets a cell" do
        expect(table.get(id, :misc, :name)).to eq name
      end

      it "finds with starts_with option" do
        expect(table.all(:starts_with => id).first.values["misc:name"]).to eq name
      end

      it "finds with offset option" do
        expect(table.all(:offset => id).first.values["misc:name"]).to eq name
      end
    end
  end
end
