classdef Dataset < handle
    properties
        name;
        doc;
        type;
        dtype;
        isConstrainedSet;
        required;
        scalar;
        shape;
        dimnames;
        attributes;
        linkable;
        definesType;
    end
    
    methods
        function obj = Dataset(source)
            obj.name = '';
            obj.doc = '';
            obj.isConstrainedSet = false;
            obj.type = '';
            obj.dtype = 'any';
            obj.required = true;
            obj.scalar = true;
            obj.definesType = false;
            
            obj.shape = {};
            obj.dimnames = {};
            obj.attributes = [];
            
            if nargin < 1
                return;
            end
            
            docKey = 'doc';
            if isKey(source, docKey)
                obj.doc = source(docKey);
            end
            
            nameKey = 'name';
            if isKey(source, nameKey)
                obj.name = source(nameKey);
            end
            
            typeKeys = {'neurodata_type_def', 'data_type_def'};
            parentKeys = {'neurodata_type_inc', 'data_type_inc'};
            hasTypeKeys = isKey(source, typeKeys);
            hasParentKeys = isKey(source, parentKeys);
            if any(hasTypeKeys)
                obj.type = source(typeKeys{hasTypeKeys});
                obj.definesType = true;
            elseif any(hasParentKeys)
                obj.type = source(parentKeys{hasParentKeys});
            end
            
            dataTypeKey = 'dtype';
            if isKey(source, dataTypeKey)
                dataType = source(dataTypeKey);
                obj.dtype = file.mapType(dataType);
            end
            
            if isKey(source, 'quantity')
                quantity = source('quantity');
                switch quantity
                    case '?'
                        obj.required = false;
                        obj.scalar = true;
                    case '*'
                        obj.required = false;
                        obj.scalar = false;
                    case '+'
                        obj.required = true;
                        obj.scalar = false;
                end
            end
            
            if source.isKey('required')
                obj.required = strcmp(source('required'), 'true');
            end
            
            obj.isConstrainedSet = ~isempty(obj.type) && ~obj.scalar;
            
            boundsKey = 'dims';
            shapeKey = 'shape';
            if isKey(source, shapeKey) && isKey(source, boundsKey)
                shape = source(shapeKey);
                obj.dimnames = source(boundsKey);
                obj.shape = file.formatShape(shape);
                if iscellstr(obj.shape)
                    obj.scalar = any(strcmp(obj.shape, '1'));
                else
                    obj.scalar = strcmp(obj.shape, '1');
                end
            else
                obj.shape = '1';
                obj.dimnames = {obj.name};
            end
            
            attributeKey = 'attributes';
            if isKey(source, attributeKey)
                sourceAttributes = source(attributeKey);
                numAttributes = length(sourceAttributes);
                obj.attributes = repmat(file.Attribute, numAttributes, 1);
                for i=1:numAttributes
                    attribute = file.Attribute(sourceAttributes{i});
                    if isempty(obj.type)
                        attribute.dependent = obj.name;
                    end
                    obj.attributes(i) = attribute;
                end
            end
            
            %linkable if named and has no attributes
            hasNoAttributes = isempty(obj.attributes) || isempty(fieldnames(obj.attributes));
            obj.linkable = ~isempty(obj.name) && hasNoAttributes;
        end
        
        function props = getProps(obj)
            props = containers.Map;
            
            %typed
            % return props as typed props with custom `data`
            % types
            
            %untyped
            % error, untyped should not hold any data.
            
            %constrained
            % error unless it defines the object.
            
            if isempty(obj.type)
                error('You shouldn''t be calling getProps on an untyped dataset');
            end
            
            if obj.isConstrainedSet && ~obj.definesType
                error('You shouldn''t be calling getProps on a constrained dataset');
            end
            
            if ~isempty(obj.dtype)
                props('data') = obj.dtype;
            end
            
            if ~isempty(obj.attributes)
                props = [props;...
                    containers.Map({obj.attributes.name}, num2cell(obj.attributes))];
            end
        end
    end
end