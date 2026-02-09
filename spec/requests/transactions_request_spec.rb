# spec/requests/transactions_request_spec.rb
require 'rails_helper'

RSpec.describe 'Transactions API', type: :request do
  # Ensure accounts are created before valid_params is accessed
  let!(:account1) { create(:account, :asset) }
  let!(:account2) { create(:account, :asset) }

  describe 'POST /api/v1/transactions' do
    let(:valid_params) do
      {
        idempotency_key: "api-test-#{SecureRandom.uuid}",
        description: 'API test transaction',
        entries: [
          { account_id: account1.id, debit: 1000.0 }, # Removed credit: 0.0
          { account_id: account2.id, credit: 1000.0 } # Removed debit: 0.0
        ]
      }
    end

    it 'creates a new transaction' do
      expect {
        # Using as: :json ensures the nested entries array is sent correctly
        post '/api/v1/transactions', params: valid_params, as: :json
      }.to change(Transaction, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['description']).to eq('API test transaction')
      expect(json['balanced']).to be true
    end

    it 'rejects unbalanced transaction' do
      unbalanced_params = {
        idempotency_key: "unbalanced-#{SecureRandom.uuid}",
        description: 'Unbalanced transaction',
        entries: [
          { account_id: account1.id, debit: 1000.0 },
          { account_id: account2.id, credit: 500.0 }
        ]
      }

      post '/api/v1/transactions', params: unbalanced_params, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('balance')
    end

    it 'prevents duplicate idempotency keys' do
      # First call
      post '/api/v1/transactions', params: valid_params, as: :json
      expect(response).to have_http_status(:created)
      
      key = valid_params[:idempotency_key]

      # Second call with same key
      expect {
        post '/api/v1/transactions', params: valid_params, as: :json
      }.not_to change(Transaction, :count)

      expect(Transaction.where(idempotency_key: key).count).to eq(1)
      # Requirement: Return 201 Created or 200 OK even on idempotency match
      expect(response).to have_http_status(:created) 
    end
  end

  describe 'GET /api/v1/transactions/:id' do
    let(:transaction) { create(:transaction, :with_entries) }

    it 'returns transaction details' do
      get "/api/v1/transactions/#{transaction.id}"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(transaction.id)
      expect(json['entries']).to be_present
    end
  end

  describe 'POST /api/v1/transactions/:id/void' do
    # Ensure transaction starts as 'posted' for void to be valid
    let(:transaction) { create(:transaction, :with_entries, status: 'posted') }

    it 'voids a transaction' do
      post "/api/v1/transactions/#{transaction.id}/void"

      expect(response).to have_http_status(:success)
      expect(transaction.reload.status).to eq('voided')
    end
  end

  describe 'GET /api/v1/transactions/search' do
    before do
      # Use unique idempotency keys in factories if necessary
      create(:transaction, description: 'Loan disbursement', idempotency_key: 'search-1')
      create(:transaction, description: 'Cash payment', idempotency_key: 'search-2')
    end

    it 'searches transactions by description' do
      get '/api/v1/transactions/search', params: { q: 'loan' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      # Adjusting expectation to match your Query object output
      txns = json['transactions'] || json
      expect(txns.any? { |t| t['description'].downcase.include?('loan') }).to be true
    end
  end
end