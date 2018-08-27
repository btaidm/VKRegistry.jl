

abstract type AbstractXmlElement end

struct TagElement <:AbstractXmlElement
	name::AbstractString
	attr::Dict{AbstractString}
end

struct CharElement <: AbstractXmlElement
	chars::AbstractString
	tags::Tuple{AbstractString,Union{Nothing,AbstractString}}
end


@enum(VkBlock,
	TypeBlk,
	EnumBlk,
	CommandBlk,
	ExtensionBlk,
	FeatureBlk)

const BASE_VALUE = 1000000000
const RANGE_SIZE = 1000

function pop_element_stack!(elements::Vector{AbstractXmlElement})
	el = pop!(elements)
	if el isa CharElement
		pop_element_stack!(elements)
	end
	return nothing
end

function get_tags(elements::Vector{AbstractXmlElement})
	iters = Iterators.take(Iterators.filter(x->isa(x,TagElement),Iterators.reverse(elements)),2)
	y = iterate(iters)
	tag1 = y[1].name
	y = iterate(iters,y[2])
	tag2 = (y === nothing ? nothing : y[1].name)
	return (tag1,tag2)
end

struct Registry
	data::AbstractString
	types::Dict{AbstractString,VkType}
	consts::Vector{AbstractString}
	commands::Dict{AbstractString,VkCommand}
	feature::Dict{VkVersion,VkFeature}
	extensions::Dict{AbstractString,VkExtension}
end


Registry(io::IO) = Registry(read(io,String))

function Registry(xml::AbstractString)
	buf = IOBuffer(xml)
	reader = EzXML.StreamReader(buf)


	vktypes = Dict{AbstractString,VkType}()
	vkconsts = AbstractString[]
	vkcommands = Dict{AbstractString,VkCommand}()
	vkfeature = Dict{VkVersion,VkFeature}()
	vkextensions = Dict{AbstractString,VkExtension}()

	type_buffer = nothing
	command_buffer = nothing
	feature_buffer = nothing
	interface_reqrem = nothing
	extn_buffer = nothing
	cur_blk = Val{nothing}

	for typ in reader
		
	end 



	Registry(xml,vktypes,vkconsts,vkcommands,vkfeature,vkextensions)
end

