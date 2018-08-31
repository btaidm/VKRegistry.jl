struct VkMember
	fieldType::VkElType
	fieldName::AbstractString
	optional::Bool
	attr::Dict{AbstractString,Any}
end

abstract type VkVariant end

struct VkValue <: VkVariant
	name::AbstractString
	value::Int
	attr::Dict{AbstractString,Any}
end

struct VkBitpos <: VkVariant
	name::AbstractString
	bitpos::UInt
	attr::Dict{AbstractString,Any}
end

struct VkAlias <: VkVariant
	name::AbstractString
	alias::AbstractString
	attr::Dict{AbstractString,Any}
end
