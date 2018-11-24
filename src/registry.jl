using Rematch, EzXML
import Base: iterate, eltype, length, size, peek
import Base: IteratorSize, IteratorEltype
import Base: SizeUnknown, IsInfinite, HasLength, HasShape 
import Base: HasEltype, EltypeUnknown

struct TakeWhile{I, F<:Base.Callable}
	takeFunc::F
	xs::I
end
IteratorSize(::Type{<:TakeWhile}) = SizeUnknown()
eltype(::Type{<:TakeWhile{I}}) where {I} = eltype(I)

function takewhile(takeFunc::F, xs::I) where {F<:Base.Callable, I}
	TakeWhile{I,F}(takeFunc,xs)
end

function iterate(it::TakeWhile{I,F}, state = nothing) where {I, F<:Base.Callable}
	if state === nothing
		next = iterate(it.xs)
		next === nothing && return nothing
	else
		next = iterate(it.xs, state)
		next === nothing && return nothing
	end
	(prev_val, xs_state) = next
	it.takeFunc(prev_val) || return nothing
	return (prev_val,xs_state)
end

struct SkipWhile{I, F<:Base.Callable}
	skipFunc::F
	xs::I
end
IteratorSize(::Type{<:SkipWhile}) = SizeUnknown()
eltype(::Type{<:SkipWhile{I}}) where {I} = eltype(I)

function skipwhile(skipFunc::F, xs::I) where {F<:Base.Callable, I}
	SkipWhile{I,F}(skipFunc,xs)
end

function iterate(it::SkipWhile{I,F}, state = nothing) where {I, F<:Base.Callable}
	if state === nothing
		next = iterate(it.xs)
		next === nothing && return nothing
		(prev_val, xs_state) = next
		d = it.skipFunc(prev_val)
		while d
			next = iterate(it.xs,xs_state)
			next === nothing && return nothing
			(prev_val, xs_state) = next
			d = it.skipFunc(prev_val)
		end
		return (prev_val,xs_state)
		
	else
		next = iterate(it.xs, state)
		next === nothing && return nothing
		(prev_val, xs_state) = next
		it.skipFunc(prev_val) || return nothing
		return (prev_val,xs_state)
	end
end



abstract type AbstractXmlElement end

struct TagElement{K <: AbstractString, V <: AbstractString} <:AbstractXmlElement
	name::AbstractString
	attr::Dict{K, V}
end

struct CharElement <: AbstractXmlElement
	chars::AbstractString
	tags::Tuple{AbstractString, Union{Nothing, AbstractString}}
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
	println("popping $el")
	if el isa CharElement
		pop_element_stack!(elements)
	end
	return nothing
end

function get_tags(elements::Vector{AbstractXmlElement})
	iters = Iterators.take(Iterators.filter(x->isa(x, TagElement), Iterators.reverse(elements)), 2)
	y = iterate(iters)
	tag1 = y[1].name
	y = iterate(iters, y[2])
	tag2 = (y === nothing ? nothing : y[1].name)
	return (tag1, tag2)
end

struct Registry
	# data::AbstractString
	types::Dict{AbstractString, VkType}
	consts::Vector{ApiConst}
	commands::Dict{AbstractString, VkCommand}
	features::Dict{VkVersion, VkFeature}
	extensions::Dict{AbstractString, VkExtension}
end


pushType!(reg::Registry, ::Nothing) = nothing
pushType!(reg::Registry, vkType::VkType) = (println("Adding Type: $(vkType)"); reg.types[vkType.name] = vkType)
pushType!(reg::Registry, vkconst::ApiConst) = push!(reg.consts, vkconst)


pushCommand!(reg::Registry, ::Nothing) = nothing
pushCommand!(reg::Registry, cmd::VkCommand) = reg.commands[cmd.name] = cmd

pushFeature!(reg::Registry, ::Nothing) = nothing
pushFeature!(reg::Registry, feat::VkFeature) = reg.features[feat.version] = feat

pushExtension!(reg::Registry, ::Nothing) = nothing
pushExtension!(reg::Registry, extn::VkExtension) = reg.extensions[extn.name] = extn

function processType(chars::String,typ::VkElType)
	@match chars begin
		"const" => make_const(typ)
		"*" => make_ptr(typ,1)
		_ where chars[1] == '[' => begin
			@match parseArrayIndex(chars) begin
				(s,_) => make_array(typ,s)
				nothing => error("Unexpected characters after name: $(chars)")
			end
		end
		_ => begin
			ptrCount = mapfoldl(x->x=='*',+,chars; init = 0)
			if ptrCount > 0 
				make_ptr(typ,ptrCount)
			else
				typ
			end
		end
	end
end


function parseArrayIndex(chars::String)
	charIter = reverse(chars)
	@match charIter[1] begin
		']' => begin
			s = 0
			for (i, digit) in enumerate(takewhile(isdigit,charIter[2:end]))
				s += parse(Int,digit) * 10^(i+1)
			end
			name_len = length(chars)-1
			@match collect(skipwhile(x->(name_len -= 1; isdigit(x) || isspace(x)),charIter[2:end]))[1] begin
				'[' => nothing
				c => error("Expected '[': found $(c)")
			end
			(s, name_len)
		end
		'[' => (0,0)
		_ => nothing
	end
end

Registry(io::IO) = Registry(read(io, String))

function Registry(xml::AbstractString)

	buf = IOBuffer(xml)
	reader = EzXML.StreamReader(buf)


	vktypes = Dict{AbstractString, VkType}()
	vkconsts = AbstractString[]
	vkcommands = Dict{AbstractString, VkCommand}()
	vkfeature = Dict{VkVersion, VkFeature}()
	vkextensions = Dict{AbstractString, VkExtension}()

	reg = Registry(vktypes, vkconsts, vkcommands, vkfeature, vkextensions)


	type_buffer = Ref{Union{Nothing, VkType}}(nothing)
	command_buffer = Ref{Union{Nothing, VkCommand}}(nothing)
	feature_buffer = Ref{Union{Nothing, VkFeature}}(nothing)
	interface_reqrem = Ref{Union{Nothing, VkReqRem}}(nothing)
	extn_buffer = Ref{Union{Nothing, VkExtension}}(nothing)
	cur_blk = Ref{Union{Nothing, VkBlock}}(nothing)

	vk_elements = AbstractXmlElement[]

	poppedTo = Ref(1)

	for typ in reader
		@match typ begin
			x where x == EzXML.READER_ELEMENT => begin
				name = nodename(reader)
				println("----- Start $(name) -----")
				
				attributes = nodeattributes(reader)
				push!(vk_elements, TagElement(name, attributes))
			end
			x where x == EzXML.READER_END_ELEMENT => begin
				for el in vk_elements[(poppedTo[]):end]
					@show el
					# @show type_buffer command_buffer feature_buffer interface_reqrem extn_buffer cur_blk el
					@match el begin
						TagElement(tag_name, tag_attrs) => begin
							@match tag_name begin
								"enums" => begin
									name = tag_attrs["name"]
									println("==========")
									println("Start EnumBlk")
									pushType!(reg, type_buffer[])
									if name == "API Constants"
										type_buffer[] = VkEnum(name, tag_attrs)
									else
										@match tag_attrs["type"] begin
											 "enum" => (type_buffer[] = VkEnum(name, tag_attrs))
											 "bitmask" => (type_buffer[] = VkBitMask(name, tag_attrs))
											 t => error("Unexpected enum type $(t) $(name)")
										end
									end
									cur_blk[] = EnumBlk
								end
								"enum" where cur_blk[] == EnumBlk => begin
									name = tag_attrs["name"]
									println("EnumBlk: enum")
									@match type_buffer[] begin
										VkEnum(enum_name, variants, _) ||
										VkBitMask(enum_name, variants, _) => begin
											if enum_name == "API Constants"
												value = get(tag_attrs, "value") do; tag_attrs["alias"]; end
												pushType!(reg, ApiConst(name, value, tag_attrs))
											else
												push!(variants,
													if haskey(tag_attrs, "value")
														VkValue(name, parse(Int, tag_attrs["value"]), tag_attrs)
													elseif haskey(tag_attrs, "bitpos")
														VkBitpos(name, parse(Int, tag_attrs["bitpos"]), tag_attrs)
													elseif haskey(tag_attrs, "alias")
														VkAlias(name, tag_attrs["alias"], tag_attrs)
													else
														error("Could not find value or bitpos in enum")
													end
												)
											end
										end
										_ => nothing
									end
									
								end

								"types" => (cur_blk[] = TypeBlk; println("Start TypeBlk"))
								"type" where cur_blk[] == TypeBlk => begin
									# println("TypeBlk: type")
									if haskey(tag_attrs, "category")
										category = tag_attrs["category"]
										pushType!(reg, type_buffer[])
										println("==========")
										println("TypeBlk: $(category)")
										@match category begin
											"basetype" ||
											"bitmask" => (type_buffer[] = VkTypeDef(tag_attrs))
											"define" => begin
												if haskey(tag_attrs, "name")
													type_buffer[] = VkDefine(tag_attrs["name"], tag_attrs)
												else
													type_buffer[] = VkDefine(tag_attrs)
												end
											end
											"enum" => (type_buffer[] = nothing)
											"funcpointer" => (type_buffer[] = VkFuncPointer(tag_attrs))
											"group" => (type_buffer[] = nothing)
											"handle" => (type_buffer[] = VkHandle(tag_attrs))
											"include" => (type_buffer[] = nothing)
											"struct" => (type_buffer[] = VkStruct(tag_attrs["name"], tag_attrs))
											"union" => (type_buffer[] = VkUnion(tag_attrs["name"], tag_attrs))
										    _ => @warn("Unexpected Category: $category", maxlog=10)
										end
									elseif haskey(tag_attrs, "requires")
										println("TypeBlk: Extern")
										requires = tag_attrs["requires"]
										pushType!(reg, type_buffer[])
										println("==========")
										if haskey(tag_attrs, "name")
											type_buffer[] = VkExternType(tag_attrs["name"], requires, tag_attrs)
										else
											error("Expected external type name; found nothing")
										end
									end
								end
								"member" where cur_blk[] == TypeBlk => begin
									@match type_buffer[] begin
										VkStruct(name, members, _) || VkUnion(name, members, _) => begin
											println("TypeBlk: member for $(name)")
											push!(members, VkMember(haskey(tag_attrs, "optional") && tag_attrs["optional"] == "true", tag_attrs))
											type_buffer[] isa VkStruct && println(type_buffer[].fields)
											type_buffer[] isa VkUnion && println(type_buffer[].variants)
										end
										_ => error("Unexpected \"member\" tag found")
									end
								end 
								"member" => error("Member outside TypeBlk")

								"commands" => (cur_blk[] = CommandBlk; println("Start CommandBlk"))
								"command" where cur_blk[] == CommandBlk => begin
									println("CommandBlk: command")
									pushCommand!(reg, command_buffer[])
									command_buffer[] = VkCommand(tag_attrs)
								end
								"param" where cur_blk[] == CommandBlk => (println("CommandBlk: param"); push!(command_buffer[].params, VkParam(tag_attrs)))

								"feature" => begin 
									println("Start FeatureBlk")
									if haskey(tag_attrs, "name")
										if haskey(tag_attrs, "number")
											cur_blk[] = FeatureBlk
											pushFeature!(reg, feature_buffer[])
											feature_buffer[] = VkFeature(tag_attrs["name"], VkVersion(tag_attrs["number"]), tag_attrs)
										else
											error("Could not find feature number")
										end
									else
										error("Could not find feature name")
									end
								end
								"require" where cur_blk[] == FeatureBlk => begin
									println("FeatureBlk: require")
									interface_reqrem[] = VkReqRem{:require}(get(tag_attrs, "profile", nothing), tag_attrs)
								end
								"remove" where cur_blk[] == FeatureBlk => begin
									println("FeatureBlk: remove")
									interface_reqrem[] = VkReqRem{:remove}(get(tag_attrs, "profile", nothing), tag_attrs)
								end
								"command" where cur_blk[] == FeatureBlk => begin
									println("FeatureBlk: command")
									pushCommand!(feature_buffer[], tag_attrs["name"], interface_reqrem[], tag_attrs)
								end
								"enum" where cur_blk[] == FeatureBlk => begin
									println("FeatureBlk: enum")
									name = tag_attrs["name"]
									if haskey(tag_attrs, "extends")
										if haskey(tag_attrs, "offset")
											offset = parse(Int,tag_attrs["offset"])
											extn_num = parse(Int,tag_attrs["extnumber"])
											value = BASE_VALUE + (extn_num - 1) * RANGE_SIZE + offset
											if haskey(tag_attrs,"dir") && tag_attrs["dir"] == "-"
												value = -value
											end
											variant = VkValue(name,value,tag_attrs)
										elseif haskey(tag_attrs,"value")
											variant = VkValue(name,parse(Int,tag_attrs["value"]),tag_attrs)
										elseif haskey(tag_attrs,"bitpos")
											variant = VkBitpos(name,parse(UInt,tag_attrs["bitpos"]),tag_attrs)
										elseif haskey(tag_attrs, "alias")
											variant = VkAlias(name, tag_attrs["alias"], tag_attrs)
										else
											error("Invalid enum extension; missing \"offset\", \"alias\" or \"bitpos\"")
										end
										pushEnum!(feature_buffer[], variant, tag_attrs["extends"], interface_reqrem[], tag_attrs)
									elseif haskey(tag_attrs, "value")
										pushConst!(feature_buffer[], name, tag_attrs["value"], interface_reqrem[], tag_attrs)
									else
										pushConst!(feature_buffer[], name, interface_reqrem[], tag_attrs)
									end
								end
								"type" where cur_blk[] == FeatureBlk => begin
									println("FeatureBlk: type")
									pushType!(feature_buffer[], tag_attrs["name"], interface_reqrem[], tag_attrs)
								end

								"extensions" => (cur_blk[] = ExtensionBlk; println("Start ExtensionBlk"))
								"extension" where cur_blk[] == ExtensionBlk => begin
									if haskey(tag_attrs, "name")
										if haskey(tag_attrs, "number")
											println("ExtensionBlk: extension")
											pushExtension!(reg, extn_buffer[])
											extn_buffer[] = VkExtension(tag_attrs["name"], parse(Int, tag_attrs["number"]), tag_attrs)
										else
											error("Could not find extension number")
										end
									else
										error("Could not find extension name")
									end
								end
								"require" where cur_blk[] == ExtensionBlk => begin
									println("ExtensionBlk: require")
									interface_reqrem[] = VkReqRem{:require}(get(tag_attrs, "profile", nothing), tag_attrs)
								end
								"remove" where cur_blk[] == ExtensionBlk => begin
									println("ExtensionBlk: remove")
									interface_reqrem[] = VkReqRem{:remove}(get(tag_attrs, "profile", nothing), tag_attrs)
								end
								"command" where cur_blk[] == ExtensionBlk => begin
									println("ExtensionBlk: command")
									pushCommand!(extn_buffer[], tag_attrs["name"], interface_reqrem[], tag_attrs)
								end
								"type" where cur_blk[] == ExtensionBlk => begin
									println("ExtensionBlk: type")
									pushType!(extn_buffer[], tag_attrs["name"], interface_reqrem[], tag_attrs)
								end
								"enum" where cur_blk[] == ExtensionBlk => begin
									println("ExtensionBlk: enum")
									name = tag_attrs["name"]
									if haskey(tag_attrs, "extends")
										if haskey(tag_attrs, "offset")
											offset = parse(Int,tag_attrs["offset"])
											extn_num = extn_buffer[].num
											value = BASE_VALUE + (extn_num - 1) * RANGE_SIZE + offset
											if haskey(tag_attrs,"dir") && tag_attrs["dir"] == "-"
												value = -value
											end
											variant = VkValue(name,value,tag_attrs)
										elseif haskey(tag_attrs,"value")
											variant = VkValue(name,parse(Int,tag_attrs["value"]),tag_attrs)
										elseif haskey(tag_attrs,"bitpos")
											variant = VkBitpos(name,parse(UInt,tag_attrs["bitpos"]),tag_attrs)
										elseif haskey(tag_attrs, "alias")
											variant = VkAlias(name, tag_attrs["alias"], tag_attrs)
										else
											error("Invalid enum extension; missing \"offset\", \"alias\" or \"bitpos\"")
										end
										pushEnum!(extn_buffer[], variant, tag_attrs["extends"], interface_reqrem[], tag_attrs)
									elseif haskey(tag_attrs, "value")
										pushConst!(extn_buffer[], name, tag_attrs["value"], interface_reqrem[], tag_attrs)
									else
										pushConst!(extn_buffer[], name, interface_reqrem[], tag_attrs)
									end
								end
								_ => nothing
							end
							# println(tag_name)
							# println(tag_attrs)
						end
						CharElement(chars, (tag, tag1)) where
								(cur_blk[] == TypeBlk &&
								tag != "usage") => begin
							@show cur_blk[], chars, tag, tag1
							@match type_buffer[] begin
								VkStruct(_, members, _) || VkUnion(_, members, _) => begin
									if !isempty(members)
										lastMember = members[end]
										@match tag begin
											"member" => (members[end] = VkMember(processType(chars,lastMember.fieldType),lastMember.fieldName,lastMember.optional,lastMember.attr))
											"type" => (members[end] = VkMember(set_type(lastMember.fieldType,chars),lastMember.fieldName,lastMember.optional,lastMember.attr))
											"name" => begin 
												
												if (arrayInfo = parseArrayIndex(chars)) != nothing
													(s,name_len) = arrayInfo
													newType = make_array(lastMember.fieldType,s)
													newName = chars[1:name_len]
													members[end] = VkMember(newType,newName,lastMember.optional,lastMember.attr)
												else
													members[end] = VkMember(lastMember.fieldType,chars,lastMember.optional,lastMember.attr)
												end
											end 
											"enum" => (members[end] = VkMember(set_array_const(lastMember.fieldType,chars),lastMember.fieldName,lastMember.optional,lastMember.attr))
											"comment" => (lastMember.attr["comment"] = (haskey(lastMember.attr,"comment") ? lastMember.attr["comment"] * "\n" : "") * chars)
											_ => nothing
										end
									end
								end
								VkTypeDef(name,typ,requires,attrs) => begin
									@match tag begin
										"type" => begin
											if chars != "typedef " && chars != "typedef" && chars != ";"
												println("Updating Typedef type")
												type_buffer[] = VkTypeDef(name,chars,requires,attrs)
											end
										end
										"name" => begin
												type_buffer[] = VkTypeDef(chars,typ,requires,attrs)
										end
										"comment" => (attrs["comment"] = (haskey(attrs,"comment") ? attrs["comment"] * "\n" : "") * chars)
										_ => error("Unexpected tag: $(tag)")
									end
								end
								VkHandle(name,dispatchable,attrs) => begin
									@match tag begin
										"type" => begin
											@match chars begin
												"VK_DEFINE_HANDLE" => nothing
												"VK_DEFINE_NON_DISPATCHABLE_HANDLE" => (type_buffer[] = VkHandle(name,false,attrs))
												"(" || ")" => nothing
												_ => error("Unexpected handle")
											end
										end
										"name" => begin
												type_buffer[] = VkHandle(chars,dispatchable,attrs)
										end
										"comment" => (attrs["comment"] = (haskey(attrs,"comment") ? attrs["comment"] * "\n" : "") * chars)
										_ => nothing
									end
								end
								VkDefine(name,attrs) => begin
									@match tag begin
										"name" => begin
												type_buffer[] = VkDefine(chars,attrs)
										end
										"type" => begin
											attrs["type"] = chars
										end
										"comment" => (attrs["comment"] = (haskey(attrs,"comment") ? attrs["comment"] * "\n" : "") * chars)
										_ => error("Unexpected tag: $(tag)")
									end
								end
								VkFuncPointer(name,ret,params,attrs) => begin
									@match tag begin
										"name" => begin
											type_buffer[] = VkFuncPointer(chars,ret,params,attrs)
										end
										"type" => begin
											@match tag1 begin
												"type" => begin
													if !isempty(params) && params[end] isa VkVar{true}
														params[end] = set_type(params[end],chars)
													else
														push!(params,VkVar{false}(chars))
													end
												end
												"types" => begin
													if !(ret isa VkElUnknown)
														if !isempty(params)
															indices = [1,1]
															ptr_count = 0
															for (b,c) in enumerate(chars)
																@match c begin
																	'*' => (ptr_count += 1)
																	'[' => (indices[1] = b)
																	']' => (indices[2] = b + 1)
																	_ => nothing
																end
															end
															
															if ptr_count > 0
																params[end] = make_ptr(params[end])
															elseif indices != [1,1]
																params[end] = make_array(params[end],parseArrayIndex(chars[indices[1]:indices[2]])[1])
															end
														end
														
														if endswith(chars,"const")
															push!(params,empty_const())
														end
													else
														start = 9
														if (indices = findfirst(" (VKAPI_PTR",chars)) != nothing
															new_end = indices[1]
															ptr_count = 0
															for (b,c) in enumerate(chars[1:(indices[1]-1)])
																if c == '*'
																	ptr_count += 1
																	if new_end == indices[1]
																		new_end = b - 1
																	end
																end
															end
															println(chars[start:(indices[1]-1)])
															if chars[start:(indices[1]-1)] != "void"
																type_buffer[] = VkFuncPointer(name,make_void(ret),params,attrs)
															elseif ptr_count != 0
																type_buffer[] = VkFuncPointer(name,VkPtr{false,ptr_count}(chars[start:new_end]),params,attrs)
															else
																type_buffer[] = VkFuncPointer(name,VkVar{false}(chars[start:(indices[1] - 1)]),params,attrs)
															end
														end
													end
												end
												_ => nothing
											end
										end
										"comment" => (attrs["comment"] = (haskey(attrs,"comment") ? attrs["comment"] * "\n" : "") * chars)
									end
								end
								_ => ()
							end
						end
						CharElement(chars, (tag, tag1)) where
								(cur_blk[] == CommandBlk &&
								tag != "usage") => begin 
							@show cur_blk[], chars, tag, tag1
						end
						_ => nothing
					end
				end
				pop_element_stack!(vk_elements)
				poppedTo[] = length(vk_elements) + 1
				println(poppedTo[])
				println("----- End -----")
			end
			x where x == EzXML.READER_TEXT => begin
				tags = get_tags(vk_elements)
				chars = nodevalue(reader)
				push!(vk_elements, CharElement(chars, tags))
			end
			_ => nothing
		end
	end
	
	pushType!(reg, type_buffer[])
	pushCommand!(reg, command_buffer[])
	pushFeature!(reg, feature_buffer[])
	pushExtension!(reg, extn_buffer[])
	
	return reg

end

