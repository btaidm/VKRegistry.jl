abstract type VkElType end

struct VkVar{C} <: VkElType
	typeName::String
end

struct VkPtr{C,N} <: VkElType
	typeName::String
end

struct VkArray{C,N} <: VkElType
	typeName::String
end

struct VkVoid <: VkElType end

struct VkElUnknown <: VkElType end

get_type(x::VkElType) = x.typeName
get_type(x::Union{VkVoid,VkElUnknown}) = nothing
set_type(x::T, typ::String) where {T <: VkElType} = T(typ)
set_type(x::VkVoid,::String) = error("Field type already set")
set_type(::VkElUnknown,typ::String) = VkVar(typ)


make_const(x::VkVar) = VkVar{true}(get_type(x))
make_ptr(x::VkVar{C}, count::UInt) where {C}= VkPtr{C,count}(get_type(x))
make_array(x::VkVar{C},s::Int) where {C} = VkArray{C,s}(get_type(x))
make_array(x::VkVar{C},s::AbstractString) where {C} = VkArray{C,Symbol(s)}(get_type(x))
