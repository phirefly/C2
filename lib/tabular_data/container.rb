module TabularData
  class Container
    attr_reader :columns, :frozen_sort, :filter

    def initialize(name, config)
      @name = name
      # useful if the sort is set via alter_query
      @frozen_sort = config.fetch(:frozen_sort, false)
      @filter = config.fetch(:filter, false)
      @query = init_query(config[:class].constantize, config.fetch(:joins, []))
      init_columns(config.fetch(:column_configs, {}), config.fetch(:columns, {}))
      set_sort(config[:sort])
    end

    def self.config_for_client(container_name, client_name)
      filename = "#{Rails.root}/config/tables/#{container_name}.yml"
      container_yaml = YAML.load_file(filename)
      key = "default"
      if container_yaml.key?(client_name)
        key = client_name
      end
      container_yaml[key].deep_symbolize_keys
    end

    def alter_query
      @query = yield(@query)
      self
    end

    def rows
      binding.pry
      results = @query

      if @sort && !@frozen_sort
        results = results.order(@sort)
      end

      apply_filter(@query)
    end

    def apply_filter(results)
      if @filter
        @filter.call(results)
      else
        results
      end
    end

    def set_state_from_params(params)
      relevant = params.permit(tables: { @name => [:sort] })
      config = relevant.fetch(:tables, {}).fetch(@name, {}) || {}
      if config.key?(:sort)
        set_sort(config[:sort])
      end
      self
    end

    def sort_params(original_params, col)
      if col.sort_dir == :asc   # flip to descending
        original_params.deep_merge(tables: { @name => {sort: '-' + col.name }})
      else
        original_params.deep_merge(tables: { @name => {sort: col.name }})
      end
    end

    private

    def set_sort(field)
      field = field || ''
      dir = field.start_with?('-') ? :desc : :asc
      field = field.gsub(/\A-/, '')

      @columns.each do |column|
        if column.name == field && !@frozen_sort
          @sort = column.sort(dir)
        else
          column.sort(nil)
        end
      end
    end

    def init_query(klass, joins)
      if joins.any?
        run_query(klass, joins)
      else
        klass.all
      end
    end

    def run_query(klass, joins)
      joins.each do |name, config|
        if config == true
          join_tables = klass.joins(name).join_sources
          join_tables[-1].left.table_alias = name
          klass.all.joins(join_tables).includes(name)
        else
          klass.all.joins(config)
        end
      end
    end

    def init_columns(config, order)
      column_hash = {}
      config.map do |name, col_config|
        if col_config == true   # short hand for "no configuration"
          col_config = {}
        end
        qualified_name = "#{@query.table_name}.#{name}"
        column_hash[name] = Column.new(name, qualified_name, col_config)
      end
      @columns = order.map{|name| column_hash[name.to_sym]}
    end
  end
end
