const VkVersion = VersionNumber

abstract type VkInterface end

struct CommandInterface <: VkInterface
	name::AbstractString
	profile::Union{Nothing,AbstractString}
end

struct TypeInterface <: VkInterface
	name::AbstractString
	profile::Union{Nothing,AbstractString}
end

struct ConstDefInterface <: VkInterface
	name::AbstractString
	value::AbstractString
	profile::Union{Nothing,AbstractString}
end

struct ApiConstInterface <: VkInterface
	name::AbstractString
	profile::Union{Nothing,AbstractString}
end

struct ExtnEnumInterface <: VkInterface
	extends::Union{Nothing,AbstractString}
	profile::Union{Nothing,AbstractString}
	variant::VkVariant
end

struct VkReqRem{R}
	profile::Union{Nothing,AbstractString}
end


struct VkFeature
	name::AbstractString
	version::VkVersion
	require::Vector{VkInterface}
	remove::Vector{VkInterface}
end

struct VkExtension
	name::AbstractString
	num::Int
	require::Vector{VkInterface}
	remove::Vector{VkInterface}
end
