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

struct VkConstArray{C} <: VkElType
	typeName::String
	enumSize::String
end

struct VkVoid <: VkElType end

struct VkElUnknown <: VkElType end

get_type(x::VkElType) = x.typeName
get_type(x::Union{VkVoid,VkElUnknown}) = nothing
set_type(x::T, typ::String) where {T <: VkElType} = T(typ)
set_type(x::VkVoid,::String) = error("Field type already set")
set_type(::VkElUnknown,typ::String) = VkVar{false}(typ)


make_const(x::VkVar) = VkVar{true}(get_type(x))
make_ptr(x::VkVar{C}, count::Integer) where {C}= VkPtr{C,count}(get_type(x))
make_ptr(x::Union{VkVoid,VkElUnknown}, count::UInt) = VkPtr{false,count}("",count)
make_array(x::VkVar{C},s::Integer) where {C} = s == 0 ? VkConstArray{C}(get_type(x), "") : VkArray{C,s}(get_type(x))
set_array_const(x::VkConstArray{C},s::AbstractString) where {C} = VkConstArray{C}(get_type(x),s)
make_void(::VkElUnknown) = VkVoid()
empty_const() = VkVar{true}("")
