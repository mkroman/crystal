require "../ast"
require "../types"

module Crystal
  class ASTNode
    def is_restriction_of?(other : ASTNode, owner)
      self == other
    end

    def is_restriction_of?(other, owner)
      raise "Bug: called #{self}.is_restriction_of?(#{other})"
    end
  end

  class SelfType
    def is_restriction_of?(type : Type, owner)
      owner.is_restriction_of?(type, owner)
    end

    def is_restriction_of?(type : SelfType, owner)
      true
    end

    def is_restriction_of?(type : ASTNode, owner)
      false
    end
  end

  class Def
    def is_restriction_of?(other : Def, owner)
      args.zip(other.args) do |self_arg, other_arg|
        self_type = self_arg.type? || self_arg.restriction
        other_type = other_arg.type? || other_arg.restriction
        return false if self_type == nil && other_type != nil
        if self_type && other_type
          return false unless self_type.is_restriction_of?(other_type, owner)
        end
      end
      true
    end
  end


  class Path
    def is_restriction_of?(other : Path, owner)
      return true if self == other

      self_type = owner.lookup_type(self)
      if self_type
        other_type = owner.lookup_type(other)
        if other_type
          return self_type.is_restriction_of?(other_type, owner)
        else
          return true
        end
      end

      false
    end

    def is_restriction_of?(other : Union, owner)
      return other.types.any? { |o| self.is_restriction_of?(o, owner) }
    end

    def is_restriction_of?(other, owner)
      false
    end
  end

  class NewGenericClass
    def is_restriction_of?(other : NewGenericClass, owner)
      return true if self == other
      return false unless name == other.name && type_vars.length == other.type_vars.length

      type_vars.zip(other.type_vars) do |type_var, other_type_var|
        return false unless type_var.is_restriction_of?(other_type_var, owner)
      end

      true
    end
  end

  class Type
    def restrict(other : Nil, owner, type_lookup, free_vars)
      self
    end

    def restrict(other : Type, owner, type_lookup, free_vars)
      if self == other
        return self
      end

      if parents.try &.any? &.is_restriction_of?(other, nil)
        return self
      end

      nil
    end

    def restrict(other : AliasType, owner, type_lookup, free_vars)
      if self == other
        self
      else
        restrict(other.remove_alias, owner, type_lookup, free_vars)
      end
    end

    def restrict(other : SelfType, owner, type_lookup, free_vars)
      restrict(owner, owner, type_lookup, free_vars)
    end

    def restrict(other : UnionType, owner, type_lookup, free_vars)
      restricted = other.union_types.any? { |union_type| is_restriction_of?(union_type, owner) }
      restricted ? self : nil
    end

    def restrict(other : HierarchyType, owner, type_lookup, free_vars)
      is_subclass_of?(other.base_type) ? self : nil
    end

    def restrict(other : Union, owner, type_lookup, free_vars)
      matches = [] of Type
      other.types.each do |ident|
        match = restrict ident, owner, type_lookup, free_vars
        matches << match if match
      end
      matches.length > 0 ? program.type_merge_union_of(matches) : nil
    end

    def restrict(other : Path, owner, type_lookup, free_vars)
      single_name = other.names.length == 1
      if single_name
        ident_type = free_vars[other.names.first]?
      end

      ident_type ||= type_lookup.lookup_type other
      if ident_type
        restrict ident_type, owner, type_lookup, free_vars
      elsif single_name
        free_vars[other.names.first] = self
      else
        self
      end
    end

    def restrict(other : NewGenericClass, owner, type_lookup, free_vars)
      nil
    end

    def restrict(other : MetaclassNode, owner, type_lookup, free_vars)
      nil
    end

    def restrict(other : ASTNode, owner, type_lookup, free_vars)
      raise "Bug: unsupported restriction: #{other}"
    end

    def is_restriction_of?(other : UnionType, owner)
      other.union_types.any? { |subtype| is_restriction_of?(subtype, owner) }
    end

    def is_restriction_of?(other : HierarchyType, owner)
      is_subclass_of? other.base_type
    end

    def is_restriction_of?(other : Type, owner)
      if self == other
        return true
      end

      if (parents = self.parents) && parents.length > 0
        return parents.any? &.is_restriction_of?(other, owner)
      end

      false
    end

    def is_restriction_of?(other : AliasType, owner)
      if self == other
        true
      else
        is_restriction_of?(other.remove_alias, owner)
      end
    end

    def is_restriction_of?(other : ASTNode, owner)
      raise "Bug: called #{self}.is_restriction_of?(#{other})"
    end

    def is_restriction_of_all?(type : UnionType)
      type.union_types.all? { |subtype| is_restriction_of? subtype, subtype }
    end

    def is_restriction_of_all?(type)
      is_restriction_of? type, type
    end
  end

  class UnionType
    def is_restriction_of?(type, owner)
      self == type || union_types.any? &.is_restriction_of?(type, owner)
    end

    def restrict(other : Type | NewGenericClass, owner, type_lookup, free_vars)
      types = [] of Type
      union_types.each do |type|
        restricted = type.restrict(other, owner, type_lookup, free_vars)
        types << restricted if restricted
      end
      program.type_merge_union_of(types)
    end
  end

  class GenericClassInstanceType
    def restrict(other : Path, owner, type_lookup, free_vars)
      ident_type = type_lookup.lookup_type other
      if ident_type
        restrict(ident_type, owner, type_lookup, free_vars)
      else
        super
      end
    end

    def restrict(other : GenericClassType, owner, type_lookup, free_vars)
      generic_class == other ? self : nil
    end

    def restrict(other : NewGenericClass, owner, type_lookup, free_vars)
      generic_class = type_lookup.lookup_type other.name
      return nil unless generic_class == self.generic_class

      generic_class = generic_class as GenericClassType
      return nil unless generic_class.type_vars.length == self.generic_class.type_vars.length

      i = 0
      type_vars.each do |name, type_var|
        other_type_var = other.type_vars[i]
        restricted = type_var.type.restrict other_type_var, owner, type_lookup, free_vars
        return nil unless restricted == type_var.type
        i += 1
      end

      self
    end

    def restrict(other : GenericClassInstanceType, owner, type_lookup, free_vars)
      return nil unless generic_class == other.generic_class

      type_vars.each do |name, type_var|
        other_type_var = other.type_vars[name]
        restricted = type_var.type.restrict(other_type_var.type, owner, type_lookup, free_vars)
        return nil unless restricted == type_var.type
      end

      self
    end
  end

  class IncludedGenericModule
    def is_restriction_of?(other : Type, owner)
      @module.is_restriction_of?(other, owner)
    end
  end

  class HierarchyType
    def is_restriction_of?(other : Type, owner)
      other = other.base_type if other.is_a?(HierarchyType)
      base_type.is_subclass_of?(other) || other.is_subclass_of?(base_type)
    end

    def restrict(other : Type, owner, type_lookup, free_vars)
      if self == other
        self
      elsif other.is_a?(UnionType)
        types = [] of Type
        other.union_types.each do |t|
          restricted = self.restrict(t, owner, type_lookup, free_vars)
          types << restricted if restricted
        end
        program.type_merge types
      elsif other.is_a?(HierarchyType)
        result = base_type.restrict(other.base_type, owner, type_lookup, free_vars) || other.base_type.restrict(base_type, owner, type_lookup, free_vars)
        result ? result.hierarchy_type : nil
      elsif other.is_subclass_of?(self.base_type)
        other.hierarchy_type
      elsif self.base_type.is_subclass_of?(other)
        self
      elsif other.module?
        if base_type.implements?(other)
          self
        else
          types = [] of Type
          base_type.subclasses.each do |subclass|
            restricted = subclass.hierarchy_type.restrict(other, owner, type_lookup, free_vars)
            types << restricted if restricted
          end
          nil
          program.type_merge_union_of types
        end
      else
        nil
      end
    end
  end

  class AliasType
    def is_restriction_of?(other, owner)
      return true if self == other

      remove_alias.is_restriction_of?(other, owner)
    end

    def restrict(other, owner, type_lookup, free_vars)
      if self == other
        self
      else
        remove_alias.restrict(other, owner, type_lookup, free_vars)
      end
    end
  end

  class Metaclass
    def restrict(other : MetaclassNode, owner, type_lookup, free_vars)
      restricted = instance_type.restrict(other.name, owner, type_lookup, free_vars)
      if restricted
        self
      else
        nil
      end
    end

    def restrict(other : HierarchyTypeMetaclass, owner, type_lookup, free_vars)
      restricted = instance_type.restrict(other.instance_type.base_type, owner, type_lookup, free_vars)
      if restricted
        self
      else
        nil
      end
    end
  end

  class FunType
    def restrict(other : Fun, owner, type_lookup, free_vars)
      inputs = other.inputs
      inputs_len = inputs ? inputs.length : 0
      output = other.output

      return nil if fun_types.length != inputs_len + 1

      if inputs
        inputs.zip(fun_types) do |input, my_input|
          restricted = my_input.restrict(input, owner, type_lookup, free_vars)
          return nil unless restricted == my_input
        end
      end

      if output
        my_output = fun_types.last
        restricted = my_output.restrict(output, owner, type_lookup, free_vars)
        return nil unless restricted == my_output
      end

      self
    end
  end
end
