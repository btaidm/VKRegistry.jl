abstract type VkElType end

struct VkVar{C} <: VkElType
	typeName::AbstractString
end

struct VkPtr{C,N} <: VkElType
	typeName::AbstractString
end

struct VkArray{C,N} <: VkElType
	typeName::AbstractString
end

struct VkVoid <: VkElType end

get_type(x::VkElType) = x.typeName
get_type(x::VkVoid) = nothing

make_const(x::VkVar) = VkVar{true}(get_type(x))
make_ptr(x::VkVar{C}, count::UInt) where {C}= VkPtr{C,count}(get_type(x))
make_array(x::VkVar{C},s::Int) where {C} = VkArray{C,s}(get_type(x))
make_array(x::VkVar{C},s::AbstractString) where {C} = VkArray{C,Symbol(s)}(get_type(x))
