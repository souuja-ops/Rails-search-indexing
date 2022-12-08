Rails.application.routes.draw do
  resources :articles
  root to: 'search#index'
  get 'search/statistics', to: 'search#statistics'
  delete 'search/statistics', to: 'search#clear_statistics'
  get 'search', to: 'search#search'
end
