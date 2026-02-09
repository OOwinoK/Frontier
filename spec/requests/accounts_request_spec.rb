require 'rails_helper'

RSpec.describe 'Accounts API', type: :request do
  describe 'GET /api/v1/accounts' do
    before do
      create_list(:account, 3)
    end

    it 'returns all accounts' do
      get '/api/v1/accounts'

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['accounts'].length).to eq(3)
    end

    it 'filters by account type' do
      create(:account, :asset)
      create(:account, :liability)

      get '/api/v1/accounts', params: { account_type: 'ASSET' }

      json = JSON.parse(response.body)
      expect(json['accounts'].all? { |a| a['account_type'] == 'ASSET' }).to be true
    end

    it 'filters by currency' do
      create(:account, currency: 'KES')
      create(:account, currency: 'USD')

      get '/api/v1/accounts', params: { currency: 'KES' }

      json = JSON.parse(response.body)
      expect(json['accounts'].all? { |a| a['currency'] == 'KES' }).to be true
    end
  end

  describe 'GET /api/v1/accounts/:id' do
    let(:account) { create(:account) }

    it 'returns account details' do
      get "/api/v1/accounts/#{account.id}"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['code']).to eq(account.code)
      expect(json['name']).to eq(account.name)
    end

    it 'returns 404 for non-existent account' do
      get '/api/v1/accounts/99999'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/accounts' do
    let(:valid_params) do
      {
        account: {
          code: 'TEST-001',
          name: 'Test Account',
          account_type: 'ASSET',
          currency: 'KES'
        }
      }
    end

    it 'creates a new account' do
      expect {
        post '/api/v1/accounts', params: valid_params
      }.to change(Account, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['code']).to eq('TEST-001')
    end

    it 'returns errors for invalid params' do
      invalid_params = { account: { code: '' } }

      post '/api/v1/accounts', params: invalid_params

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to be_present
    end
  end

  describe 'GET /api/v1/accounts/:id/balance' do
    let(:account) { create(:account, current_balance: 5000.0000) }

    it 'returns current balance' do
      get "/api/v1/accounts/#{account.id}/balance"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['balance']).to eq(5000.0)
    end
  end
end
