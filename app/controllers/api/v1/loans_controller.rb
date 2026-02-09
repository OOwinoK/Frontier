# app/controllers/api/v1/loans_controller.rb

module Api
  module V1
    class LoansController < ApplicationController
      # POST /api/v1/loans/disburse
      def disburse
        service = LoanDisbursementService.new
        
        result = service.disburse(
          borrower_name: params[:borrower_name],
          principal_amount: params[:principal_amount].to_f,
          origination_fee: params[:origination_fee]&.to_f || 0,
          currency: params[:currency] || 'KES',
          loan_reference: params[:loan_reference],
          metadata: params[:metadata] || {}
        )
        
        if result[:success]
          render json: {
            loan_account: account_json(result[:loan_account]),
            transaction: transaction_json(result[:transaction]),
            net_disbursement: result[:net_disbursement]
          }, status: :created
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/loans/:loan_account_id/repay
      def repay
        service = LoanRepaymentService.new
        
        result = service.process_repayment(
          loan_account_id: params[:loan_account_id],
          principal_amount: params[:principal_amount]&.to_f || 0,
          interest_amount: params[:interest_amount]&.to_f || 0,
          fee_amount: params[:fee_amount]&.to_f || 0,
          payment_reference: params[:payment_reference],
          metadata: params[:metadata] || {}
        )
        
        if result[:success]
          render json: {
            transaction: transaction_json(result[:transaction]),
            total_amount: result[:total_amount],
            remaining_balance: result[:remaining_balance]
          }
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/loans/:loan_account_id/writeoff
      def writeoff
        service = LoanWriteoffService.new
        
        result = service.writeoff(
          loan_account_id: params[:loan_account_id],
          writeoff_amount: params[:writeoff_amount]&.to_f,
          reason: params[:reason],
          reference: params[:reference],
          metadata: params[:metadata] || {}
        )
        
        if result[:success]
          render json: {
            transaction: transaction_json(result[:transaction]),
            writeoff_amount: result[:writeoff_amount],
            remaining_balance: result[:remaining_balance]
          }
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/loans/:loan_account_id/recover
      def recover
        service = LoanWriteoffService.new
        
        result = service.recover(
          loan_account_id: params[:loan_account_id],
          recovery_amount: params[:recovery_amount].to_f,
          reference: params[:reference],
          metadata: params[:metadata] || {}
        )
        
        if result[:success]
          render json: {
            transaction: transaction_json(result[:transaction]),
            recovery_amount: result[:recovery_amount],
            new_balance: result[:new_balance]
          }
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/loans/:loan_account_id
      def show
        loan_account = Account.find(params[:loan_account_id])
        
        render json: {
          loan_account: account_json(loan_account),
          balance: AccountBalanceQuery.current(loan_account.id),
          recent_transactions: TransactionHistoryQuery.for_account(
            loan_account.id,
            page: 1,
            per_page: 10
          )
        }
      end
      
      private
      
      def account_json(account)
        {
          id: account.id,
          code: account.code,
          name: account.name,
          currency: account.currency,
          current_balance: account.current_balance.to_f,
          active: account.active
        }
      end
      
      def transaction_json(transaction)
        {
          id: transaction.id,
          idempotency_key: transaction.idempotency_key,
          description: transaction.description,
          posted_at: transaction.posted_at,
          status: transaction.status
        }
      end
    end
  end
end
