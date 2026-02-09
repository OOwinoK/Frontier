# app/queries/balance_sheet_query.rb
#
# Query class for generating balance sheet reports
# Balance Sheet: Assets = Liabilities + Equity

class BalanceSheetQuery
  class BalanceSheetError < StandardError; end
  
  class << self
    # Generate balance sheet
    def generate(as_of: Date.current, currency: nil)
      # Get trial balance first (uses cached data if available)
      trial_balance = TrialBalanceQuery.generate(as_of: as_of, currency: currency)
      
      # Extract by account type
      assets = extract_type(trial_balance, 'ASSET')
      liabilities = extract_type(trial_balance, 'LIABILITY')
      equity = extract_type(trial_balance, 'EQUITY')
      
      # Calculate totals
      total_assets = assets[:total]
      total_liabilities = liabilities[:total]
      total_equity = equity[:total]
      
      # Verify accounting equation
      verify_accounting_equation!(total_assets, total_liabilities, total_equity)
      
      {
        as_of: as_of,
        currency: currency,
        assets: assets,
        liabilities: liabilities,
        equity: equity,
        total_assets: total_assets,
        total_liabilities: total_liabilities,
        total_equity: total_equity,
        total_liabilities_and_equity: total_liabilities + total_equity,
        balanced: (total_assets - (total_liabilities + total_equity)).abs < 0.01,
        generated_at: Time.current
      }
    end
    
    # Generate comparative balance sheet (multiple periods)
    def comparative(dates:, currency: nil)
      balance_sheets = dates.map do |date|
        generate(as_of: date, currency: currency)
      end
      
      {
        periods: balance_sheets,
        currency: currency,
        generated_at: Time.current
      }
    end
    
    # Generate balance sheet with ratios
    def with_ratios(as_of: Date.current, currency: nil)
      balance_sheet = generate(as_of: as_of, currency: currency)
      
      # Calculate financial ratios
      ratios = calculate_ratios(balance_sheet)
      
      balance_sheet.merge(ratios: ratios)
    end
    
    private
    
    def extract_type(trial_balance, account_type)
      type_data = trial_balance[:accounts_by_type].find { |t| t[:account_type] == account_type }
      
      return { accounts: [], total: 0 } unless type_data
      
      # For assets, use debit balance (normal balance)
      # For liabilities/equity, use credit balance (normal balance)
      total = if account_type == 'ASSET'
        type_data[:total_debit] - type_data[:total_credit]
      else
        type_data[:total_credit] - type_data[:total_debit]
      end
      
      {
        accounts: type_data[:accounts],
        total_debit: type_data[:total_debit],
        total_credit: type_data[:total_credit],
        total: total
      }
    end
    
    def verify_accounting_equation!(assets, liabilities, equity)
      difference = (assets - (liabilities + equity)).abs
      
      if difference > 0.01
        raise BalanceSheetError,
              "Balance sheet doesn't balance! Assets: #{assets}, L+E: #{liabilities + equity}, Diff: #{difference}"
      end
    end
    
    def calculate_ratios(balance_sheet)
      total_assets = balance_sheet[:total_assets]
      total_liabilities = balance_sheet[:total_liabilities]
      total_equity = balance_sheet[:total_equity]
      
      # Current assets (usually cash + receivables)
      current_assets = balance_sheet[:assets][:accounts]
                                     .select { |a| a[:account_code].match?(/CASH|RECEIVABLE/) }
                                     .sum { |a| a[:debit] - a[:credit] }
      
      # Current liabilities (usually payables)
      current_liabilities = balance_sheet[:liabilities][:accounts]
                                         .select { |a| a[:account_code].match?(/PAYABLE/) }
                                         .sum { |a| a[:credit] - a[:debit] }
      
      {
        debt_to_equity_ratio: total_equity > 0 ? (total_liabilities / total_equity).round(2) : nil,
        equity_ratio: total_assets > 0 ? (total_equity / total_assets * 100).round(2) : nil,
        debt_ratio: total_assets > 0 ? (total_liabilities / total_assets * 100).round(2) : nil,
        current_ratio: current_liabilities > 0 ? (current_assets / current_liabilities).round(2) : nil
      }
    end
  end
end
