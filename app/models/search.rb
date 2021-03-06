class Search
  include DateParser
  attr_accessor :models, :properties, :operators, :vals, :queries
  
  def initialize(hash)
    hash        = hash.collect{|k,v| {k.to_sym => v}}.inject({}){|s,x| s+=x}    
    @models, @properties, @operators, @vals = *prepare_hash(hash)
    @queries    = {}
  end
  
  def self.get_operators(property)
    if property.type==DataMapper::Associations::ManyToOne::Relationship
      return [["eql", "equal"], ["not", "not equal"]]
    elsif [DataMapper::Types::Serial, Integer, Float, DateTime, Date, Time].include?(property.type)
      return [["lt", "less than"], ["lte", "less than equal"], ["eql", "equal to"], ["gt", "greater than"], ["gte", "greater than equal"], ["not", "not equal to"]]
    elsif [DataMapper::Types::Text, String].include?(property.type)
      return [["eql", "equal"], ["like", "like"], ["in","in"]]
    elsif [DataMapper::Types::Boolean].include?(property.type)
      return [["true", "true"], ["false", "false"]]
    elsif property.type.class==Class
      return [["eql", "equal"], ["not", "not equal"]]
    else
      return []
    end
  end

  def process
    relationship_to_properties
    transform_enums
    prepare_queries if queries.length==0
    return chain_queries
  end

  private
  def chain_queries
    #No chaining
    return {models.uniq.first.to_s.snake_case.to_sym => models.first.all(queries.values.first).aggregate(:id)} if models.uniq.length==1

    #chaining
    last_ids = {}; ids = []; result = {}; last_model = nil
    models.each{|model|
      # we use the ids here becuase datamapper is very slow dealing with collections
      # after all, an ORM is not meant for aggregating data
      # TODO check if this has been addressed in the latest version
      next if model == last_model # i am not sure if uniq preserves array order, which is why we are not relying on models.uniq to achieve this
      ids = model.all(queries[model].merge(last_ids)).aggregate(:id)
      result[model.to_s.snake_case.to_sym] = ids
      last_ids = {"#{model.to_s.snake_case}_id".to_sym => ids}
      last_model = model
    }
    result
  end

  def transform_enums
    #transform values to symbols if property is a flag map/enum
    properties.each_with_index{|p, idx| 
      prop = models[idx].properties.find{|x| x.name==p.to_sym} 
      if prop.type.name==""
        vals[idx] = prop.type.flag_map[vals[idx].to_i]
      end
    }
  end
  
  def prepare_queries
    # preparing queries
    models.each_with_index{|model, idx|
      queries[model]||= {}
      prop = properties[idx].to_sym.send(operators[idx].to_sym)
      if [Hash, Mash].include?(vals[idx].class) and property_type = model.properties.find{|x| x.name==prop.target}.type and [Date, DateTime].include?(property_type)
        vals[idx] = parse_date(vals[idx].collect{|k,v| {k.to_sym => v}}.inject({}){|s,x| s+=x})
        queries[model][prop] = vals[idx]
      elsif queries[model][prop]
        val = queries[model][prop]
        queries[model][prop] = []
        queries[model][prop].push(val)
      else
        queries[model][prop] = vals[idx]
      end
    }
  end

  def relationship_to_properties
    #check if property here is actually a relationship ?
    models.each_with_index{|m, idx|
      if not m.properties.find{|x| x.name==properties[idx].to_sym} and m.relationships[properties[idx].to_sym]
        properties[idx]=m.relationships[properties[idx].to_sym].child_key.map{|x| x.name}[0]
      end
    }
  end

  def prepare_hash(hash)
    [prepare_models(hash[:model]), prepare_properties(hash[:property]), prepare_operators(hash[:operator]), prepare_vals(hash[:value])]
  end

  def prepare_models(models)
    models.to_a.collect{|x| Kernel.const_get(x[1].camelcase)}
  end
  
  def prepare_operators(operators)
    operators.to_a.collect{|x| x[1]}
  end
  
  def prepare_vals(vals)
      vals.values.map{|x| x.values.first} if hash[:value]
  end
  
  def prepare_properties(properties)
    properties.to_a.collect{|x| x[1]}
  end
end
