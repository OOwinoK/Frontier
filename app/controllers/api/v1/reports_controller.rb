# app/controllers/api/v1/reports_controller.rb

module Api
  module V1
    class ReportsController < ApplicationController
      # GET /api/v1/reports/trial_balance
      def trial_balance
        as_of = params[:as_of] ? Date.parse(params[:as_of]) : Date.current
        currency = params[:currency]
        
        report = TrialBalanceQuery.generate(as_of: as_of, currency: currency)
        
        render json: report
      end
      
      # GET /api/v1/reports/balance_sheet
      def balance_sheet
        as_of = params[:as_of] ? Date.parse(params[:as_of]) : Date.current
        currency = params[:currency]
        
        report = if params[:with_ratios] == 'true'
          BalanceSheetQuery.with_ratios(as_of: as_of, currency: currency)
        else
          BalanceSheetQuery.generate(as_of: as_of, currency: currency)
        end
        
        render json: report
      end
      
      # GET /api/v1/reports/loan_aging
      def loan_aging
        refresh = params[:refresh] == 'true'
        currency = params[:currency]
        
        report = LoanAgingQuery.generate(refresh: refresh, currency: currency)
        
        render json: report
      end
      
      # GET /api/v1/reports/loan_aging/summary
      def loan_aging_summary
        currency = params[:currency]
        summary = LoanAgingQuery.summary(currency: currency)
        
        render json: summary
      end
      
      # GET /api/v1/reports/loan_aging/top_overdue
      def top_overdue_loans
        limit = (params[:limit] || 10).to_i
        currency = params[:currency]
        
        loans = LoanAgingQuery.top_overdue(limit: limit, currency: currency)
        
        render json: { loans: loans, limit: limit, currency: currency }
      end
      
      # GET /api/v1/reports/account_balances
      def account_balances
        account_type = params[:account_type]
        currency = params[:currency]
        
        balances = AccountBalanceQuery.by_type(account_type, currency: currency)
        
        render json: { balances: balances, account_type: account_type, currency: currency }
      end
      
      # GET /api/v1/reports/balance_summary
      def balance_summary
        currency = params[:currency]
        summary = AccountBalanceQuery.summary_by_type(currency: currency)
        
        render json: summary
      end
      
      # POST /api/v1/reports/refresh_views
      def refresh_views
        LoanAgingReport.refresh!
        
        render json: {
          message: 'Materialized views refreshed successfully',
          refreshed_at: Time.current
        }
      end
    end
  end
end
