Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :accounts, only: [:index, :show, :create, :update] do
        member do
          patch :deactivate
          patch :activate
          get :balance
          get :history
        end
      end
      
      resources :transactions, only: [:index, :show, :create] do
        member do
          post :void
          post :reverse
        end
        collection do
          get :search
        end
      end
      
      scope :loans do
        post 'disburse', to: 'loans#disburse'
        post ':loan_account_id/repay', to: 'loans#repay'
        post ':loan_account_id/writeoff', to: 'loans#writeoff'
        post ':loan_account_id/recover', to: 'loans#recover'
        get ':loan_account_id', to: 'loans#show'
      end
      
      scope :reports do
        get 'trial_balance', to: 'reports#trial_balance'
        get 'balance_sheet', to: 'reports#balance_sheet'
        get 'loan_aging', to: 'reports#loan_aging'
        get 'loan_aging/summary', to: 'reports#loan_aging_summary'
        get 'loan_aging/top_overdue', to: 'reports#top_overdue_loans'
        get 'account_balances', to: 'reports#account_balances'
        get 'balance_summary', to: 'reports#balance_summary'
        post 'refresh_views', to: 'reports#refresh_views'
      end
    end
  end
  
  get 'health', to: proc { [200, {}, ['OK']] }
end