function fvstr = fillValidators(propnames, props, namespacereg)
fvstr = '';
for i=1:length(propnames)
    nm = propnames{i};
    prop = props(nm);
    
    %if readonly and value exists then ignore
    if isa(prop, 'file.Attribute') && prop.readonly && ~isempty(prop.value)
        continue;
    end
    if startsWith(class(prop), 'file.')
        validationBody = fillUnitValidation(nm, prop, namespacereg);
    else %primitive type
        validationBody = fillDtypeValidation(nm, prop);
    end
    hdrstr = ['function val = validate_' nm '(obj, val)'];
    if isempty(validationBody)
        fcnStr = [hdrstr newline 'end'];
    else
        fcnStr = strjoin({hdrstr ...
            file.addSpaces(strtrim(validationBody), 4) 'end'}, newline);
    end
    fvstr = [fvstr newline fcnStr];
end
end

function fuvstr = fillUnitValidation(name, prop, namespacereg)
fuvstr = '';
constr = {};
if isa(prop, 'file.Dataset')
    if isempty(prop.type)
        fuvstr = strjoin({fuvstr...
            fillDtypeValidation(name, prop.dtype)...
            fillDimensionValidation(prop.dtype, prop.shape)...
            }, newline);
    elseif prop.isConstrainedSet
        try
            fullname = namespacereg.getFullClassName(prop.type);
        catch ME
            if ~endsWith(ME.identifier, 'Namespace:NotFound')
                rethrow(ME);
            end
            
            warning('NWB:Fill:Validators:NamespaceNotFound',...
                ['Namespace could not be found for type `%s`.' ...
                '  Skipping Validation for property `%s`.'], prop.type, name);
            return;
        end
        fuvstr = strjoin({fuvstr...
            ['constrained = { ''' fullname ''' };']...
            ['types.util.checkSet(''' name ''', struct(), constrained, val);']...
            }, newline);
    else
        try
            fullname = namespacereg.getFullClassName(prop.type);
        catch ME
            if ~endsWith(ME.identifier, 'Namespace:NotFound')
                rethrow(ME);
            end
            
            warning('NWB:Fill:Validators:NamespaceNotFound',...
                ['Namespace could not be found for type `%s`.' ...
                '  Skipping Validation for property `%s`.'], prop.type, name);
            return;
        end
        fuvstr = [fuvstr newline ...
            fillDtypeValidation(name, fullname)];
    end
elseif isa(prop, 'file.Group')
    if isempty(prop.type)
        namedprops = struct();
        
        %process datasets
        %if type, check if constrained
        % if constrained, add to constr
        % otherwise, check type once
        %otherwise, check dtype
        for i=1:length(prop.datasets)
            ds = prop.datasets(i);
            
            if isempty(ds.type)
                namedprops.(ds.name) = ds.dtype;
            else
                type = namespacereg.getFullClassName(ds.type);
                if ds.isConstrainedSet
                    constr = [constr {type}];
                else
                    namedprops.(ds.name) = type;
                end
            end
        end
        
        %process groups
        %if type, check if constrained
        % if constrained, add to constr
        % otherwise, check type once
        %otherwise, error.  This shouldn't happen.
        for i=1:length(prop.subgroups)
            sg = prop.subgroups(i);
            sgfullname = namespacereg.getFullClassName(sg.type);
            if isempty(sg.type)
                error('Weird case with two untyped groups');
            end
            
            if isempty(sg.name)
                constr = [constr {sgfullname}];
            else
                namedprops.(sg.name) = sgfullname;
            end
        end
        
        %process attributes
        if ~isempty(prop.attributes)
            namedprops = [namedprops;...
                containers.Map({prop.attributes.name}, ...
                {prop.attributes.dtype})];
        end
        
        %process links
        if ~isempty(prop.links)
            linktypes = {prop.links.type};
            linkNamespaces = cell(size(linktypes));
            for i=1:length(linktypes)
                lt = linktypes{i};
                linkNamespaces{i} = namespacereg.getNamespace(lt);
            end
            linkTypenames = strcat('types.', linkNamespaces, '.', linktypes);
            namedprops = [namedprops; ...
                containers.Map({prop.links.name}, linkTypenames)];
        end
        
        propnames = fieldnames(namedprops);
        fuvstr = 'namedprops = struct();';
        for i=1:length(propnames)
            nm = propnames{i};
            fuvstr = strjoin({fuvstr...
                ['namedprops.' nm ' = ''' namedprops.(nm) ''';']}, newline);
        end
        fuvstr = strjoin({fuvstr...
            ['constrained = {' strtrim(evalc('disp(constr)')) '};']...
            ['types.util.checkSet(''' name ''', namedprops, constrained, val);']...
            }, newline);
    elseif prop.isConstrainedSet
        fullname = namespacereg.getFullClassName(prop.type);
        fuvstr = strjoin({fuvstr...
            sprintf('constrained = {''%s''};', fullname),...
            ['types.util.checkSet(''' name ''', struct(), constrained, val);']...
            }, newline);
    else
        fulltypename = namespacereg.getFullClassName(prop.type);
        fuvstr = fillDtypeValidation(name, fulltypename);
    end
elseif isa(prop, 'file.Attribute')
    fuvstr = fillDtypeValidation(name, prop.dtype);
else %Link
    fullname = namespacereg.getFullClassName(prop.type);
    fuvstr = fillDtypeValidation(name, fullname);
end
end

function fdvstr = fillDimensionValidation(type, shape)
if strcmp(type, 'any') || strcmp(type, 'char')
    fdvstr = '';
    return;
end

shape = strcat('[', shape, ']');
if iscellstr(shape)
    shape = strjoin(shape, ', ');
end
shape = strcat('{', shape, '}');

fdvstr = strjoin({...
    'if isa(val, ''types.untyped.DataStub'')' ...
    '    valsz = val.dims;' ...
    'else' ...
    '    valsz = size(val);'...
    'end' ...
    ['validshapes = ' shape ';']...
    'types.util.checkDims(valsz, validshapes);'}, newline);
end

%NOTE: can return empty strings
function fdvstr = fillDtypeValidation(name, type)
if isstruct(type)
    fnames = fieldnames(type);
    fdvstr = strjoin({...
        'if isempty(val) || isa(val, ''types.untyped.DataStub'')'...
        '    return;'...
        'end'...
        'if ~istable(val) && ~isstruct(val) && ~isa(val, ''containers.Map'')'...
        ['    error(''Property `' name '` must be a table,struct, or containers.Map.'');']...
        'end'...
        'vprops = struct();'...
        }, newline);
    vprops = cell(length(fnames),1);
    for i=1:length(fnames)
        nm = fnames{i};
        if isa(type.(nm), 'containers.Map')
            %ref
            switch type.(nm)('reftype')
                case 'region'
                    rt = 'RegionView';
                case 'object'
                    rt = 'ObjectView';
            end
            typeval = ['types.untyped.' rt];
        else
            typeval = type.(nm);
        end
        vprops{i} = ['vprops.' nm ' = ''' typeval ''';'];
    end
    fdvstr = [fdvstr, newline, strjoin(vprops, newline), newline, ...
        'val = types.util.checkDtype(''' name ''', vprops, val);'];
else
    fdvstr = '';
    if isa(type, 'containers.Map')
        %ref
        ref_t = type('reftype');
        switch ref_t
            case 'region'
                rt = 'RegionView';
            case 'object'
                rt = 'ObjectView';
        end
        ts = ['types.untyped.' rt];
        %there is no objective way to guarantee a reference refers to the
        %correct target type
        tt = type('target_type');
        fdvstr = ['% Reference to type `' tt '`' newline];
    elseif strcmp(type, 'any')
        fdvstr = '';
        return;
    else
        ts = strrep(type, '-', '_');
    end
    fdvstr = [fdvstr ...
        'val = types.util.checkDtype(''' name ''', ''' ts ''', val);'];
end
end