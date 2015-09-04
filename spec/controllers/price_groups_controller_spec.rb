require "rails_helper"
require 'controller_spec_helper'

RSpec.describe PriceGroupsController do
  render_views

  before(:all) { create_users }

  before :each do
    @authable=FactoryGirl.create(:facility)
    @price_group=FactoryGirl.create(:price_group, :facility => @authable)
    @params={ :facility_id => @authable.url_name }
  end

  context 'index' do
    before :each do
      @method = :get
      @action = :index
    end

    it_should_allow_managers_only do
      expect(assigns(:price_groups)).to be_kind_of Array
      expect(assigns(:price_groups)).to eq(@authable.price_groups)
    end
  end

  context 'new' do
    before :each do
      @method=:get
      @action=:new
    end

    it_should_allow_managers_only do
      expect(assigns(:price_group)).to be_kind_of PriceGroup
      is_expected.to render_template 'new'
    end
  end

  context 'create' do
    before :each do
      @method = :post
      @action = :create
      @params.merge!(:price_group => FactoryGirl.attributes_for(:price_group, :facility_id => @authable.id))
    end

    it_should_allow_managers_only :redirect do
      expect(assigns(:price_group)).to be_kind_of PriceGroup
      is_expected.to set_flash
      assert_redirected_to [@authable, assigns(:price_group)]
    end
  end

  context 'with price group id' do
    before(:each) { @params.merge!(:id => @price_group.id) }

    context 'show' do

      before :each do
        @method = :get
        @action = :show
      end

      it_should_allow_managers_only :redirect do
        expect(assigns(:price_group)).to be_kind_of PriceGroup
        expect(assigns(:price_group)).to eq(@price_group)
        assert_redirected_to accounts_facility_price_group_path(@authable, assigns(:price_group))
      end

    end


    context 'users' do

      before :each do
        @method = :get
        @action = :users
      end

      it_should_allow_managers_only do
        expect(assigns(:user_members)).to be_kind_of ActiveRecord::Relation
        expect(assigns(:tab)).to eq(:users)
        is_expected.to render_template 'show'
      end

    end


    context 'accounts' do

      before :each do
        @method = :get
        @action=:accounts
      end

      it_should_allow_managers_only do
        expect(assigns(:account_members)).to be_kind_of ActiveRecord::Relation
        expect(assigns(:tab)).to eq(:accounts)
        is_expected.to render_template 'show'
      end

    end


    context 'edit' do

      before :each do
        @method = :get
        @action = :edit
      end

      it_should_allow_managers_only do
        expect(assigns(:price_group)).to be_kind_of PriceGroup
        expect(assigns(:price_group)).to eq(@price_group)
        is_expected.to render_template 'edit'
      end

    end


    context 'update' do

      before :each do
        @method = :put
        @action = :update
        @params.merge!(:price_group => FactoryGirl.attributes_for(:price_group, :facility_id => @authable.id))
      end

      it_should_allow_managers_only :redirect do
        expect(assigns(:price_group)).to be_kind_of PriceGroup
        expect(assigns(:price_group)).to eq(@price_group)
        is_expected.to set_flash
        assert_redirected_to [@authable, @price_group]
      end

    end


    context 'destroy' do

      before :each do
        @method = :delete
        @action = :destroy
      end

      it_should_allow_managers_only :redirect do
        expect(assigns(:price_group)).to be_kind_of PriceGroup
        expect(assigns(:price_group)).to eq(@price_group)
        should_be_destroyed @price_group
        assert_redirected_to facility_price_groups_url
      end

    end
  end
end
