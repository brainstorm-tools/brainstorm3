classdef plotlystream < handle
    % Interface to Plotly's real-time graphing API.
    % Initialize a Stream object with a stream_id found in
    % {plotly_domain}/settings. Real-time graphs are
    % initialized with a call to plotly that embeds your unique
    % `stream_id`s in each of the graph's traces. The plotlystream
    % class plots data to these traces, as identified with the unique
    % stream_id, in real-time. Every viewer of the graph sees
    % the same data at the same time.
    
    %----CLASS PROPERTIES----%
    properties
        Response
        Specs
    end
    
    properties (Access=private)
        URL
        ErrorURL
        Connection
        ErrorConnection
        Stream
        ErrorStream
    end
    
    %----CLASS METHODS----%
    methods
        
        %----CONSTRUCTOR---%
        function obj = plotlystream(request)
            
            %default stream settings
            obj.Specs.Token = '';
            
            %look for specified streaming domain
            try
                config = loadplotlyconfig;
                obj.Specs.Host  = config.plotly_streaming_domain;
            catch
                obj.Specs.Host = 'http://stream.plot.ly';
            end
            
            %check if ssl is enabled
            if any(strfind(obj.Specs.Host,'https://') == 1)
                obj.Specs.SSLEnabled = true;
            else
                obj.Specs.SSLEnabled = false;                
            end
            
            %add http if not present on host
            if ~obj.Specs.SSLEnabled
                if ~any(strfind(obj.Specs.Host,'http://') == 1)
                    obj.Specs.Host = ['http://' obj.Specs.Host];
                end 
            end
            
            %specify handler
            if obj.Specs.SSLEnabled
                obj.Specs.Handler = sun.net.www.protocol.https.Handler;
            else
                obj.Specs.Handler = sun.net.www.protocol.http.Handler;
            end
            
            %initialize connection settings
            obj.Specs.ReconnectOn = {'','200','408'};
            obj.Specs.Timeout = 500;
            obj.Specs.Chunklen = 14;
            obj.Specs.Closed = true;
            obj.Specs.ConnectAttempts = 0;
            obj.Specs.ConnectDelay = 1;
            obj.Specs.MaxConnectAttempts = 5;
            
            %initialize output response
            obj.Response = '';
            
            %check for correct input structure
            if nargin > 0
                
                if ischar(request)
                    
                    obj.Specs.Token = request;
                    
                elseif isstruct(request)
                    
                    %check for tokens (required)
                    if (isfield(request,'token'))
                        obj.Specs.Token = request.token;
                    else
                        error(['Oops! You did not properly specify a stream token! Please check out the ', ....
                            'online documentation found @ plot.ly/matlab for more information or contact ',...
                            'chuck@plot.ly']);
                    end
                    
                    if isfield(request,'host')
                        obj.Specs.Host = request.host;
                    end
                    
                    if isfield(request,'timeout')
                        obj.Specs.Timeout = request.timeout;
                    end
                    
                    if isfield(request,'handler')
                        obj.Specs.Handler= request.handler;
                    end
                    
                    if isfield(request,'chunklen')
                        obj.Specs.Chunklen= request.chunklen;
                    end
                else
                    error(['Oops! It appears that the specified input argument used to ',...
                        'initialize the plotlystream object was not of type char or struct. ',...
                        'Please check out the online documentation found @ plot.ly/matlab ',...
                        'for more information or contact chuck@plot.ly']);
                end
                
            else
                error(['Oops! You did not properly specify a stream token! Please check out the ', ....
                    'online documentation found @ plot.ly/matlab for more information or contact ',...
                    'chuck@plot.ly']);
            end
        end
         
        %-----------OPEN STREAM-----------%
        function obj = open(obj)
            
            try obj.connect;
                
                %Connection successful!
                fprintf('\n[Connection Successful]\n\n');
                
                %update state
                obj.resetretries;
                obj.Specs.Closed = false;
                
            catch ME
                
                error(['Oops! The following error occured when trying to write to the stream: ',...
                    ME.message '. Please check the online documentation ', ...
                    'found @ plot.ly/matlab for more information or contact chuck@plot.ly']);
            end
            
        end
        
        %-----------CONNECT TO STREAM-----------%
        function obj = connect(obj)
            obj.URL = java.net.URL([],obj.Specs.Host,obj.Specs.Handler);
            
            % Get the proxy information using MathWorks facilities for unified proxy
            % preference settings.
            mwtcp = com.mathworks.net.transport.MWTransportClientPropertiesFactory.create();
            proxy = mwtcp.getProxy();

            % Open a connection to the URL.
            if isempty(proxy)
                obj.Connection = obj.URL.openConnection(); %throws an I/O exception
            else
                obj.Connection = obj.URL.openConnection(proxy); %throws an I/O exception
            end

            obj.Connection.setChunkedStreamingMode(obj.Specs.Chunklen)
            obj.Connection.setRequestMethod('POST');
            obj.Connection.setDoOutput(true);
            obj.Connection.setReadTimeout(obj.Specs.Timeout);
            obj.Connection.setRequestProperty('plotly-streamtoken', obj.Specs.Token);
            obj.Stream = obj.Connection.getOutputStream; %throws an I/O exception
        end
        
        %-----------WRITE STREAM-----------%
        function obj = write(obj,request)
            
            if nargin ~= 2
                error(['Oops! It appears that not enough input arguments were ',...
                    'specified to the write method of your plotlystream object. ',...
                    'Please check out the online documentation found @ plot.ly/matlab ',...
                    'for more information or contact chuck@plot.ly']);
            else
                if ~isstruct(request)
                    error(['Oops! It appears that the input argument to the write method ',...
                        'of your plotlystream object is not a structure array as required.  ',...
                        'Please check out the online documentation found @ plot.ly/matlab ',...
                        'for more information or contact chuck@plot.ly']);
                end
                
                body = request;
                
                %make sure we did not close the stream
                if(~obj.Specs.Closed)
                    try
                        %write to stream
                        obj.Stream.write(unicode2native(sprintf([m2json(body) '\n']),''));
                    catch ME
                        
                        %error due to stream not being open (creation of Stream object)
                        if(strcmp(ME.message, 'Attempt to reference field of non-structure array.'))
                            error(['Oops! A connection has not yet been established. Please open',...
                                ' a connection by firsting calling the ''open'' method of your',...
                                ' plotlystream object.']);
                        else
                            
                            %---reconnect---%
                            obj.getresponse;
                            if any(strcmp(obj.Specs.ReconnectOn,obj.Response))
                                if~strcmp(obj.Response,'')
                                    fprintf(['\n[Connection Failed due to HTTP error: ' obj.Response '] Reconnecting...\n\n']);
                                else
                                    fprintf('\n[Connection Failed] Reconnecting...\n\n');
                                end
                                obj.reconnect;
                                
                                %add recursion call to not drop data
                                obj.write(body);
                            else
                                error(['Oops! The following error occured when trying to write to the stream: ',...
                                    ME.message '. No attempt to reconnect was made beacause the response code ',...
                                    'of: ' obj.Response ' did not match any of the response codes specified in ',...
                                    'the obj.Specs.ReconnectOn parameter. Please check out the online documentation ', ...
                                    'found @ plot.ly/matlab for more information or contact chuck@plot.ly']);
                            end
                        end
                    end
                else
                    error(['Oops! The connection is closed. Please open ',...
                        'a connection by calling the ''open'' method of your ',...
                        'plotlystream object.']);
                end
            end
        end
        
        %-----------CLOSE STREAM-----------%
        function obj = close(obj)
            try
                obj.Stream.close;
            catch ME
                if(strcmp(ME.message, 'Attempt to reference field of non-structure array.'))
                    error(['Oops! A connection has not yet been established. Please open',...
                        ' a connection by firsting calling the ''open'' method of your',...
                        ' plotlystream object.']);
                end
            end
            %update reconnect state
            obj.resetretries;
            obj.Specs.Closed = true;
        end
        
        %-----------RECONNECT-----------%
        function obj = reconnect(obj)
            try
                obj.Specs.ConnectAttempts = obj.Specs.ConnectAttempts + 1;
                
                %try to connect
                obj.connect;
                
                %Connection successful!
                fprintf('\n[Connection Successful]\n\n');
                
                %update state
                obj.resetretries;
                obj.Specs.Closed = false;
            catch
                if(obj.Specs.ConnectAttempts <= obj.Specs.MaxConnectAttempts)
                    fprintf(['\n[Connection Failed] Attempt:' num2str(obj.Specs.ConnectAttempts) ' to reconnect...'])
                    pause(obj.Specs.ConnectDelay);
                    obj.Specs.ConnectDelay = 2*obj.Specs.ConnectDelay; %delay grows by factor of 2
                    obj.reconnect;
                else
                    fprintf('\n');
                    error(['Oops! All attempts to reconnect were unsuccessful. ',...
                        'Please check out the online documentation found @ plot.ly/matlab ',...
                        'for more information or contact chuck@plot.ly']);
                end
            end
        end
        
        %-----------GET RESPONSE-----------%
        function obj = getresponse(obj)
            try
                obj.Response = num2str(obj.Connection.getResponseCode);
            catch ME
                if(strcmp(ME.message, 'Attempt to reference field of non-structure array.'))
                    error(['Oops! A connection has not yet been established. Please open',...
                        ' a connection by firsting calling the ''open'' method of your',...
                        ' plotlystream object.']);
                end
            end
        end
        
        %-----------RESET RETRIES-----------%
        function obj = resetretries(obj)
            %reset the connect counter and delay
            obj.Specs.ConnectAttempts = 0;
            obj.Specs.ConnectDelay = 1;
        end
        
    end
end


