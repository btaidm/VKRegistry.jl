struct VkMember
	fieldType::VkElType
	fieldName::String
	optional::Bool
	attr::Attributes
end

VkMember(optional::Bool,attr) = VkMember(VkElUnknown(),"",optional,attr)

abstract type VkVariant end

struct VkValue <: VkVariant
	name::String
	value::Int
	attr::Attributes
end

struct VkBitpos <: VkVariant
	name::String
	bitpos::UInt
	attr::Attributes
end

struct VkAlias <: VkVariant
	name::String
	alias::String
	attr::Attributes
end
