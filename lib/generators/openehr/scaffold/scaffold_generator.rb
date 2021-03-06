require 'openehr/rm'
require 'openehr/am'
require 'openehr/parser'
require 'generators/openehr'
require 'generators/openehr/assets/assets_generator'
require 'generators/openehr/model/model_generator'
require 'generators/openehr/migration/migration_generator'
require 'generators/openehr/controller/controller_generator'
require 'generators/openehr/helper/helper_generator'
require 'generators/openehr/i18n/i18n_generator'
require 'rails/generators'

module Openehr
  module Generators
    class ScaffoldGenerator < ArchetypedBase
      source_root File.expand_path("../templates", __FILE__)

      def create_root_folder
        empty_directory File.join("app/views", controller_file_path)
      end
      
      def generate_index
        generate_view  "index.html.erb"
      end

      def generate_show
        generate_view  "show.html.erb"
      end

      def generate_edit
        generate_view "edit.html.erb"
      end

      def generate_new
        generate_view 'new.html.erb'
      end
      def generate_form
        generate_view "_form.html.erb"
      end

      invoke Openehr::Generators::ControllerGenerator, @archetype
      invoke Openehr::Generators::HelperGenerator, @archetype
      invoke Openehr::Generators::AssetsGenerator, @archetype
      invoke Openehr::Generators::I18nGenerator, @archetype

      def append_locale_route
        unless File.exist? 'config/routes.rb'
          template 'routes.rb', File.join("config", 'routes.rb')
        end
        inject_into_file 'config/routes.rb',
        "  resources :#{controller_file_path}\n",
        :after => "Application.routes.draw do\n"
      end

      def insert_locale_swither
        unless File.exist? 'app/views/layouts/application.html.erb'
          template 'application.html.erb', File.join('app/views/layouts', 'application.html.erb')
        end
        inject_into_file 'app/views/layouts/application.html.erb', <<SWITCHER, :after => "<body>\n"
<div id="banner">
 <%= form_tag '', :method => 'get', class: 'locale' do %>
  <%= select_tag 'locale',
      options_for_select(LANGUAGES, I18n.locale.to_s), 
      onchange: 'this.form.submit()' %>
 <% end %>
</div>
SWITCHER
      end

      def generate_layout_stylesheet
        template 'layout.css.scss', File.join('app/assets/stylesheets', 'layout.css.scss')
      end

      def insert_uncountable_inflection
        inflections_file_path = 'config/initializers/inflections.rb'
        unless File.exist? inflections_file_path
          empty_directory File.join('config/initializers')
          template 'inflections.rb', File.join('config/initializers', 'inflections.rb')
        else
          append_to_file inflections_file_path, <<INFLECTION
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable %w(  )
end
INFLECTION
        end
        insert_into_file inflections_file_path, model_name, :after => "inflect.uncountable %w( "
      end

      def append_set_locale
        unless File.exist? 'app/controllers/application_controller.rb'
          template 'application_controller.rb', File.join("app/controllers", 'application_controller.rb')
        end
        inject_into_file 'app/controllers/application_controller.rb', <<LOCALE, :after => "class ApplicationController < ActionController::Base\n"
  before_action :set_locale

  def set_locale
    I18n.locale = params[:locale] || session[:locale] || I18n.default_locale
    session[:locale] = I18n.locale
  end
LOCALE
      end

      invoke Openehr::Generators::ModelGenerator, @archetype
      invoke Openehr::Generators::MigrationGenerator

      protected

      def index_data(tree = archetype.definition)
        data = tree.attributes.inject([]) do |values, attribute|
          attribute.children.each do |child|
            if child.rm_type_name == 'ELEMENT'
              values << child.node_id
            else
              values.concat index_data(child) if child.respond_to? :attributes
            end
          end if attribute.has_children?
          values
        end
        data
      end

      def generate_view(filename)
        template filename, File.join("app/views", controller_file_path, filename)
      end

      def show_format(cobj)
        h = case cobj.rm_type_name
            when 'ELEMENT'
              show_element cobj
            when 'EVENT'
              show_component cobj
            when 'INTERVAL_EVENT'
              show_component cobj
            when 'OBSERVATION'
              show_component cobj
            when 'ACTION'
              show_component cobj
            else
              show_component cobj
            end
        h
      end
 
      def show_component(cobj)
        html = ''# "<strong>#{cobj.rm_type_name.humanize} t(\".#{cobj.node_id}\")</strong>:<br/>\n"
        unless cobj.respond_to? :attributes
          html += "#{cobj.rm_type_name}\n"
        else
          html += cobj.attributes.inject("") do |form, attr|
            form += "<p><strong>#{attr.rm_attribute_name.humanize}:</strong>"
            form += attr.children.inject("") {|h,c| h += show_format c; h}
            form += "</p>\n"
          end
        end
        html
      end
      
      def show_element(cobj)
        html = "<strong><%= t('.#{cobj.node_id}') %></strong>: "
        value = cobj.attributes[0].children[0]
        case value.rm_type_name
        when 'DV_CODED_TEXT', 'DvCodedText'
          html += "<%= @#{model_name}.#{cobj.node_id} %><br/>\n"
        when 'DV_QUANTITY', 'DvQuantity'
          units = value.list[0].units unless value.list.nil? or value.list.empty?
          html += "<%= @#{model_name}.#{cobj.node_id} %>#{units}<br/>\n"
        else
          html += "<%= @#{model_name}.#{cobj.node_id} %><br/>\n"
        end
        html
      end

      def form_format(cobj)
        html = case cobj.rm_type_name
               when 'ELEMENT'
                 form_element cobj
               when 'EVENT'
                 "<strong><%= t('.#{cobj.node_id}') %></strong>: <%= f.text_field :#{cobj.node_id} %><br/>\n" +
                 form_component(cobj)
               when 'INTERVAL_EVENT'
                 "<strong><%= t('.#{cobj.node_id}') %></strong>: <%= f.text_field :#{cobj.node_id} %><br/>\n"
               else
                 form_component cobj
               end
        return html
      end

      def form_component(cobj)
        html = '' #"<strong>#{cobj.rm_type_name.humanize} <%= t('.#{cobj.node_id}') %></strong>:<br/>\n"
        unless cobj.respond_to? :attributes
          html += "#{cobj.rm_type_name}<br/>\n"
        else
          html += cobj.attributes.inject("") do |form, attr|
            form += "<p><strong><%= t('.#{cobj.node_id}') %></strong>:"
            form += attr.children.inject('') {|h,c| h += form_format c}
            form += "</p>\n"
          end
        end
        html
      end

      def form_element(cobj)
        html = ''
        if cobj.respond_to? :attributes
          cobj.attributes.each do |attr|
            unless attr.nil?
              html = "<strong><%= t('.#{cobj.node_id}') %></strong>: "
              html += form_field attr.children[0], cobj.node_id
            end
          end
        end
        html
      end

      def form_field(cobj, label)
        form = case cobj.rm_type_name
               when 'DV_TEXT', 'DvText'
                 "<%= f.text_field :#{label} %><br/>\n"
               when 'DV_CODED_TEXT', 'DvCodedText'
                 "<%= f.select :#{label}, #{code_list_to_hash(cobj.attributes[0].children[0].code_list)} %><br/>\n"
               when 'DV_QUANTITY', 'DvQuantity'
                 units = cobj.list[0].units unless cobj.list.nil? or cobj.list.empty?
                 "<%= f.number_field :#{label} %> #{units}<br/>\n"
               else
                 "<%= f.text_field :#{label} %><br/>\n"
               end
        form
      end

      def code_list_to_hash(code_list)
        html = code_list.inject('') do |form, item|
          form += "t('.#{item}') => '#{item}', "
        end
        html[0..-3] unless html.nil?
      end
    end
  end
end

