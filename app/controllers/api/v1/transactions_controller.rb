# app/controllers/api/v1/transactions_controller.rb

module Api
  module V1
    class TransactionsController < ApplicationController
      before_action :set_transaction, only: [:show, :void, :reverse]
      
      # GET /api/v1/transactions
      def index
        result = TransactionHistoryQuery.all_transactions(
          page: params[:page] || 1,
          per_page: params[:per_page] || 50,
          start_date: params[:start_date],
          end_date: params[:end_date],
          status: params[:status]
        )
        
        render json: result
      end
      
      # GET /api/v1/transactions/:id
      def show
        render json: transaction_json(@transaction, detailed: true)
      end
      
      # POST /api/v1/transactions
      def create
        service = TransactionService.new
        
        # FIX: Convert ActionController::Parameters to standard Hashes
        # This ensures the service can access keys like :account_id or :debit
        sanitized_entries = if params[:entries].is_a?(Array)
                              params[:entries].map { |e| e.respond_to?(:to_unsafe_h) ? e.to_unsafe_h : e }
                            else
                              []
                            end

        sanitized_metadata = params[:metadata].respond_to?(:to_unsafe_h) ? params[:metadata].to_unsafe_h : (params[:metadata] || {})
        
        @transaction = service.create_transaction(
          idempotency_key: params[:idempotency_key],
          description: params[:description],
          entries: sanitized_entries,
          posted_at: params[:posted_at],
          metadata: sanitized_metadata
        )
        
        render json: transaction_json(@transaction, detailed: true), status: :created
      rescue TransactionService::TransactionError => e
        # Using :unprocessable_entity (422) as requested
        puts "DEBUG ERROR: #{e.message}"
        render json: { error: e.message, errors: service.errors }, status: :unprocessable_entity
      end
      
      # POST /api/v1/transactions/:id/void
      def void
        service = TransactionService.new
        reversal = service.void_transaction(@transaction)
        
        render json: {
          original_transaction: transaction_json(@transaction),
          reversal_transaction: transaction_json(reversal),
          message: 'Transaction voided successfully'
        }
      rescue TransactionService::ValidationError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
      
      # POST /api/v1/transactions/:id/reverse
      def reverse
        service = TransactionService.new
        reversal = service.reverse_transaction(@transaction)
        
        render json: {
          original_transaction: transaction_json(@transaction),
          reversal_transaction: transaction_json(reversal),
          message: 'Transaction reversed successfully'
        }
      rescue TransactionService::ValidationError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
      
      # GET /api/v1/transactions/search
      def search
        result = TransactionHistoryQuery.search(
          params[:q],
          page: params[:page] || 1,
          per_page: params[:per_page] || 50
        )
        
        render json: result
      end
      
      private
      
      def set_transaction
        @transaction = Transaction.find(params[:id])
      end
      
      def transaction_json(transaction, detailed: false)
        data = {
          id: transaction.id,
          idempotency_key: transaction.idempotency_key,
          description: transaction.description,
          posted_at: transaction.posted_at,
          status: transaction.status,
          created_at: transaction.created_at
        }
        
        if detailed
          data.merge!(
            total_debits: transaction.total_debits.to_f,
            total_credits: transaction.total_credits.to_f,
            balanced: transaction.balanced?,
            entries: transaction.entries.map { |e| entry_json(e) },
            metadata: transaction.metadata
          )
        end
        
        data
      end
      
      def entry_json(entry)
        {
          id: entry.id,
          account_id: entry.account_id,
          account_code: entry.account.code,
          account_name: entry.account.name,
          debit: entry.debit&.to_f,
          credit: entry.credit&.to_f,
          description: entry.description
        }
      end
    end
  end
end