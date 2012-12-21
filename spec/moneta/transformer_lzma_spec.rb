# Generated by generate.rb
require 'helper'

describe_moneta "transformer_lzma" do
  def new_store
    Moneta.build do
      use :Transformer, :value => :lzma
      adapter :Memory
    end
  end

  include_context 'setup_store'
  it_should_behave_like 'null_objectkey_stringvalue'
  it_should_behave_like 'null_stringkey_stringvalue'
  it_should_behave_like 'null_hashkey_stringvalue'
  it_should_behave_like 'store_objectkey_stringvalue'
  it_should_behave_like 'store_stringkey_stringvalue'
  it_should_behave_like 'store_hashkey_stringvalue'
  it_should_behave_like 'returndifferent_objectkey_stringvalue'
  it_should_behave_like 'returndifferent_stringkey_stringvalue'
  it_should_behave_like 'returndifferent_hashkey_stringvalue'
  it 'should transform value' do
    store['key'] = 'value'
    store.load('key', :raw => true).should == ::LZMA.compress('value')
  end
end
