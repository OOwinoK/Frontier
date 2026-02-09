# frozen_string_literal: true

class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from ArgumentError, with: :bad_request
  
  private
  
  def not_found(exception)
    render json: {
      error: 'Not Found',
      message: exception.message
    }, status: :not_found
  end
  
  def unprocessable_entity(exception)
    render json: {
      error: 'Unprocessable Entity',
      message: exception.message
    }, status: :unprocessable_entity
  end
  
  def bad_request(exception)
    render json: {
      error: 'Bad Request',
      message: exception.message
    }, status: :bad_request
  end
  
  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
