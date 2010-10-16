module Cream::Generators 
  module Config
    module DeviseUsers
      attr_accessor :user_helper

      def configure_devise_users
        @user_helper = UserHelper.new user_generator
        
        devise_default_user if !has_model? :user
        
        # if User model is NOT configured with devise strategy
        Strategy.insert_devise_strategy :user, :defaults if !has_devise_user? :user
        
        devise_admin_user if admin_user?
      end
      
      def devise_default_user
        user_helper.create_devise_model :user
      end

      def devise_admin_user
        # if app does NOT have a Admin model
        user_helper.create_admin_user if !has_model? :admin

        # insert default devise Admin strategy
        Strategy.insert_devise_strategy :admin, :defaults if has_model? :admin
      end

      def create_admin_user
        logger.debug 'create_admin_user'
        user_helper.create_user_model :admin
        # remove any current inheritance
        Inherit.remove_inheritance :admin
        # and make Admin model inherit from User model 
        Inherit.inherit_model :user => :admin
      end 

      # Helpers

      class UserHelper
        attr_accessor :user_generator
        
        def initialize user_gen
          @user_generator = user_gen
        end
        
        def create_user_model user = :user
          rgen "#{user_generator} model #{user}"
        end  

        def devise_users?
          has_devise_user?(:user) && has_devise_user?(:admin)
        end

        def has_devise_user? user
          return true if user == :admin && !admin_user?
          begin
            read_model(user) =~ /devise/
          rescue Exception => e
            logger.info "Exception for #has_devise_user? #{user}: #{e.message}"
            false
          end
        end

        # Must be ORM specific!
        def create_devise_model user = :user
          rgen "#{user_generator} #{user}"
        end
      end   
      
      module Inherit 
        self << class        
          extend Rails3::Assist::UseMacro        
          use_helpers :model

          def remove_inheritance user
            File.remove_from model_file user, :content => /<\s*ActiveRecord::Base/
          end  

          def inherit_model hash                 
            subclass    = hash.keys.first
            superclass  = hash.values.first.to_s.camelize
            File.replace_content_from model_file subclass, :where => /class Admin/, :with => "class Admin < #{superclass}"
          end
        end
      end
    
      module Strategy
        self << class
          extend Rails3::Assist::UseMacro        
          use_helpers :model

          def insert_devise_strategy model_name, *names
            names = devise_default_strategies if names.first == :defaults        
            insert_into_model model_name do
              "devise #{*names}"
            end
          end
        
          def devise_default_strategies
            [:database_authenticatable, :confirmable, :recoverable, :rememberable, :trackable, :validatable]
          end          
        end      
      end
    end
  end  
end

