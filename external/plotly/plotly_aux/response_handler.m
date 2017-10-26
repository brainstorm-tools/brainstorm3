function response_handler(response_body, varargin)
    % varargin is the optional `extras` struct
    % returned by urlread2
    if(length(varargin)==1)
        extras = varargin{1};
        if (strcmp(extras.allHeaders.Content_Type, 'image/jpeg') || ...
            strcmp(extras.allHeaders.Content_Type, 'image/png') || ...
            strcmp(extras.allHeaders.Content_Type, 'application/pdf') || ...
            strcmp(extras.allHeaders.Content_Type, 'image/svg+xml'))
            return;
        end
    end

    response_struct = loadjson(response_body);

    if(isempty(fieldnames(response_struct)))
        error(['Unexpected Response: ', response_body])
    end
    f = fieldnames(response_struct);

    if ((any(strcmp(f, 'error')) && (~isempty(response_struct.error))) || ...
        (length(varargin)==1 && varargin{1}.status.value ~= 200))
        % If the error string is nonempty
        % then check the `extras`
        % object for a status code
        % and embed that in the response
        if(length(varargin)==1)
            extras = varargin{1};
            error(['BadResponse:StatusCode',num2str(extras.status.value)], response_struct.error)
        else
            error(response_struct.error)
        end
    end
    if any(strcmp(f,'warning'))
        fprintf(response_struct.warning)
    end
    if any(strcmp(f,'message'))
        fprintf(response_struct.message)
    end

end
