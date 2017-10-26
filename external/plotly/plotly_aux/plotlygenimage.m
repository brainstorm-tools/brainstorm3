function plotlygenimage(figure_or_data, filename, varargin)

    [pathstr, name, ext] = fileparts(filename);
    if nargin < 3
        format = ext(2:length(ext));
    else
        format = varargin{1};
    end

    if (strcmp(ext,'') && nargin < 3)
        filename = [filename, '.png'];
        format = 'png';
    elseif( ~strcmp(ext, '') && nargin < 3)
        format = ext(2:length(ext));
    elseif(strcmp(ext,'') && nargin==3)
        filename = [filename, '.', varargin{1}];
    else
        filename = [filename, '.', varargin{1}];
    end

    if isstruct(figure_or_data)
        figure = figure_or_data;
    elseif iscell(figure_or_data)
        figure = struct('data', data);
    end

    body = struct('figure', figure, 'format', format);

    payload = m2json(body);

    [un, key, domain] = signin;

    url = [domain, '/apigenimage/'];

    headers = struct(...
                    'name',...
                        {...
                            'plotly-username',...
                            'plotly-apikey',...
                            'plotly-version',...
                            'plotly-platform',...
                            'user-agent'
                        },...
                    'value',...
                        {...
                            un,...
                            key,...
                            plotly_version,...
                            'MATLAB',...
                            'MATLAB'
                        });
    % return the response as bytes -
    % convert the bytes to unicode chars if the response fails or isn't (pdf, png, or jpeg)
    % ... gnarly!
    [response_string, extras] = urlread2(url, 'Post', payload, headers, 'CAST_OUTPUT', false);
    if( extras.status.value ~= 200 || ...
      ~(strcmp(extras.allHeaders.Content_Type, 'image/jpeg') || ...
        strcmp(extras.allHeaders.Content_Type, 'image/png') || ...
        strcmp(extras.allHeaders.Content_Type, 'application/pdf')))
        response_string = native2unicode(response_string);
    end

    response_handler(response_string, extras);
    image_data = response_string;
    
    fileID = fopen(filename, 'w');
    fwrite(fileID, image_data);
    fclose(fileID);
end
