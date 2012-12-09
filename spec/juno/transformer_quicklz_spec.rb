# Generated by generate.rb
require 'helper'

describe_juno "transformer_quicklz" do
  def new_store
    Juno.build do
      use :Transformer, :value => :quicklz
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
end