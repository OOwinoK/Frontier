# frozen_string_literal: true

# app/controllers/api/v1/accounts_controller.rb

module Api
  module V1
    class AccountsController < Api::V1::ApplicationController
      before_action :set_account, only: [:show, :update, :deactivate, :activate, :balance, :history]
      
      # GET /api/v1/accounts
      def index
        @accounts = Account.active
        @accounts = @accounts.by_type(params[:account_type]) if params[:account_type]
        @accounts = @accounts.by_currency(params[:currency]) if params[:currency]
        @accounts = @accounts.order(:code).page(params[:page]).per(params[:per_page] || 50)
        
        render json: {
          accounts: @accounts.map { |a| account_json(a) },
          meta: pagination_meta(@accounts)
        }
      end
      
      # GET /api/v1/accounts/:id
      def show
        render json: account_json(@account, detailed: true)
      end
      
      # POST /api/v1/accounts
      def create
        @account = Account.new(account_params)
        
        if @account.save
          render json: account_json(@account, detailed: true), status: :created
        else
          render json: { errors: @account.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/accounts/:id
      def update
        if @account.update(account_params)
          render json: account_json(@account, detailed: true)
        else
          render json: { errors: @account.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/accounts/:id/deactivate
      def deactivate
        @account.deactivate!
        render json: account_json(@account, detailed: true)
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end
      
      # PATCH /api/v1/accounts/:id/activate
      def activate
        @account.activate!
        render json: account_json(@account, detailed: true)
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end
      
      # GET /api/v1/accounts/:id/balance
      def balance
        as_of = params[:as_of] ? Date.parse(params[:as_of]) : Date.current
        balance_data = as_of == Date.current ? 
          AccountBalanceQuery.current(@account.id) : 
          AccountBalanceQuery.historical(@account.id, as_of)
        
        render json: balance_data
      end
      
      # GET /api/v1/accounts/:id/history
      def history
        render json: TransactionHistoryQuery.for_account(
          @account.id,
          page: params[:page] || 1,
          per_page: params[:per_page] || 50,
          start_date: params[:start_date],
          end_date: params[:end_date]
        )
      end
      
      private
      
      def set_account
        @account = Account.find(params[:id])
      end
      
      def account_params
        params.require(:account).permit(:code, :name, :description, :account_type, :currency, :parent_account_id)
      end
      
      def account_json(account, detailed: false)
        data = {
          id: account.id,
          code: account.code,
          name: account.name,
          account_type: account.account_type,
          currency: account.currency,
          current_balance: account.current_balance.to_f,
          active: account.active
        }
        
        data.merge!(
          description: account.description,
          total_entries_count: account.total_entries_count,
          balance_updated_at: account.balance_updated_at
        ) if detailed
        
        data
      end
    end
  end
end