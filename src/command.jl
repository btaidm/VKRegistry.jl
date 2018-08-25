struct VkParam
	typ::VkElType
	name::AbstractString
	optional::Bool
	attr::Dict{AbstractString,Any}
end

struct VkCommand
	name::AbstractString
	ret::VkElType
	params::Vector{VkParam}
	attr::Dict{AbstractString,Any}
end
