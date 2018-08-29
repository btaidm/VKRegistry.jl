using Rematch

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
	cur_blk = Ref{Union{Nothing,VkBlock}}(nothing)

	vk_elements = AbstractXmlElement[]

	poppedTo = Ref(1)

	for typ in reader
		@match typ begin
			x where x == EzXML.READER_ELEMENT => begin
				name = nodename(reader)
				attributes = nodeattributes(reader)
				push!(vk_elements,TagElement(name,attributes))
			end
			x where x == EzXML.READER_END_ELEMENT => begin
				for el in vk_elements[(poppedTo[]):end]
					@match el begin
						TagElement(tag_name, tag_attr) => begin
							@match tag_name begin
								"enums" => begin
									println("Found enums")
								end
								# "enum" where cur_blk[] == EnumBlk => begin 
								end
								"types" => nothing
								# "type" where cur_blk[] == TypeBlk =>
								_ => nothing
							end
							# println(tag_name)
							# println(tag_attr)
						end
						CharElement(char, (tag, tag1)) => begin
							@show char,tag,tag1
						end
						_ => nothing
					end
				end
				pop_element_stack!(vk_elements)
				poppedTo[] = length(vk_elements) != 0 ? length(vk_elements) : 1
			end
			x where x == EzXML.READER_TEXT => begin
				tags = get_tags(vk_elements)
				chars = nodevalue(reader)
				push!(vk_elements,CharElement(chars,tags))
			end
			_ => nothing
		end
	end


	Registry(xml,vktypes,vkconsts,vkcommands,vkfeature,vkextensions)
end

