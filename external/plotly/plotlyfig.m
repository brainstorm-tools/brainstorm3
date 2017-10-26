classdef plotlyfig < handle
    
    %----CLASS PROPERTIES----%
    properties
        data; % data of the plot
        layout;  % layout of the plot
        url; % url response of making post request
        error; % error response of making post request
        warning; % warning response of making post request
        message; % message response of making post request
        
    end
    
    properties (SetObservable)
        UserData;% credentials/configuration/verbose
        PlotOptions; % filename,fileopt,world_readable
    end
    
    properties (Hidden = true)
        PlotlyDefaults; % plotly specific conversion defualts
        State; % state of plot (FIGURE/AXIS/PLOTS)
    end
    
    properties (Access = private)
        PlotlyReference; % load the plotly reference
        InitialState; % inital userdata
    end
    
    %----CLASS METHODS----%
    methods
        
        %----CONSTRUCTOR---%
        function obj = plotlyfig(varargin)
            
            %-Core-%
            obj.data = {};
            obj.layout = struct();
            obj.url = '';
            
            %-UserData-%
            try
                [obj.UserData.Username,...
                    obj.UserData.ApiKey,...
                    obj.UserData.PlotlyDomain] = signin;
            catch
                errkey = 'plotlyfigConstructor:notSignedIn';
                error(errkey, plotlymsg(errkey));
            end
            
            obj.UserData.Verbose = true;
            
            %-PlotOptions-%
            obj.PlotOptions.CleanFeedTitle = true; 
            obj.PlotOptions.FileName = '';
            obj.PlotOptions.FileOpt = 'new';
            obj.PlotOptions.WorldReadable = true;
            obj.PlotOptions.ShowURL = true;
            obj.PlotOptions.OpenURL = true;
            obj.PlotOptions.Strip = true;
            obj.PlotOptions.Visible = 'on';
            obj.PlotOptions.TriangulatePatch = false; 
            
            % offline options
            obj.PlotOptions.Offline = false;
            obj.PlotOptions.ShowLinkText = true; 
            obj.PlotOptions.LinkText = obj.get_link_text; 
            obj.PlotOptions.IncludePlotlyjs = true;
            
            %-PlotlyDefaults-%
            obj.PlotlyDefaults.MinTitleMargin = 80;
            obj.PlotlyDefaults.TitleHeight = 0.01;
            obj.PlotlyDefaults.TitleFontSizeIncrease = 40; 
            obj.PlotlyDefaults.FigureIncreaseFactor = 1.5;
            obj.PlotlyDefaults.AxisLineIncreaseFactor = 1.5;
            obj.PlotlyDefaults.MarginPad = 0;
            obj.PlotlyDefaults.MaxTickLength = 20;
            obj.PlotlyDefaults.ExponentFormat = 'none';
            obj.PlotlyDefaults.ErrorbarWidth = 6;
            obj.PlotlyDefaults.ShowBaselineLegend = false;
            obj.PlotlyDefaults.Bargap = 0;
            obj.PlotlyDefaults.CaptionMarginIncreaseFactor = 1.2; 
            obj.PlotlyDefaults.MinCaptionMargin = 80;
            
            %-State-%
            obj.State.Figure = [];
            obj.State.Axis = [];
            obj.State.Plot = [];
            obj.State.Text = [];
            obj.State.Legend = [];
            obj.State.Colorbar = [];
            
            % figure object management
            obj.State.Figure.NumAxes = 0;
            obj.State.Figure.NumPlots = 0;
            obj.State.Figure.NumLegends = 0;
            obj.State.Figure.NumColorbars = 0;
            obj.State.Figure.NumTexts = 0;
            
            %-PlotlyReference-%
            obj.PlotlyReference = [];
            
            %-InitialState-%
            obj.InitialState.Username = obj.UserData.Username;
            obj.InitialState.ApiKey = obj.UserData.ApiKey;
            obj.InitialState.PlotlyDomain = obj.UserData.PlotlyDomain;
            
            % initialize figure handle
            fig_han = [];
            
            % initialize autoupdate key
            updatekey = false;
            
            % parse inputs
            switch nargin
                
                case 0
                case 1
                    % check for figure handle
                    if ishandle(varargin{1})
                        if strcmp(get(varargin{1},'type'),'figure')
                            fig_han = varargin{1};
                            updatekey = true;
                        end
                    else
                        errkey = 'plotlyfigConstructor:invalidInputs';
                        error(errkey , plotlymsg(errkey));
                    end
                    
                otherwise
                    
                    % check for figure handle
                    if ishandle(varargin{1})
                        if strcmp(get(varargin{1},'type'),'figure')
                            fig_han = varargin{1};
                            updatekey = true;
                            parseinit = 2;
                        end
                    else
                        parseinit = 1;
                    end
                    
                    % check for proper property/value structure
                    if mod(length(parseinit:nargin),2) ~= 0
                        errkey = 'plotlyfigConstructor:invalidInputs';
                        error(errkey , plotlymsg(errkey));
                    end
                    
                    % parse property/values
                    for a = parseinit:2:nargin
                        if(strcmpi(varargin{a},'filename'))
                            obj.PlotOptions.FileName = varargin{a+1};
                            % overwrite if filename provided
                            obj.PlotOptions.FileOpt = 'overwrite';
                        end
                        if(strcmpi(varargin{a},'fileopt'))
                            obj.PlotOptions.FileOpt = varargin{a+1};
                        end
                        if(strcmpi(varargin{a},'world_readable'))
                            obj.PlotOptions.WorldReadable = varargin{a+1};
                        end
                        if(strcmpi(varargin{a},'link'))
                            obj.PlotOptions.ShowURL = varargin{a+1};
                        end
                        if(strcmpi(varargin{a},'open'))
                            obj.PlotOptions.OpenURL = varargin{a+1};
                        end
                        if(strcmpi(varargin{a},'strip'))
                            obj.PlotOptions.Strip = varargin{a+1};
                        end
                        if(strcmpi(varargin{a},'visible'))
                            obj.PlotOptions.Visible = varargin{a+1};
                        end
                        if(strcmpi(varargin{a},'offline'))
                            obj.PlotOptions.Offline = varargin{a+1};
                        end
                        if(strcmpi(varargin{a},'showlink'))
                            obj.PlotOptions.ShowLinkText = varargin{a+1};
                        end
                        if(strcmpi(varargin{a},'linktext'))
                            obj.PlotOptions.LinkText = varargin{a+1};
                        end
                        if(strcmpi(varargin{a},'include_plotlyjs'))
                            obj.PlotOptions.IncludePlotlyjs = varargin{a+1};
                        end
                        if(strcmpi(varargin{a},'layout'))
                            obj.layout= varargin{a+1};
                        end
                        if(strcmpi(varargin{a},'data'))
                            obj.data = varargin{a+1};
                        end
                    end
            end
            
            % create figure/axes if empty
            if isempty(fig_han)
                fig_han = figure;
                axes;
            end
            
            % plotly figure default style
            set(fig_han,'Name',obj.PlotOptions.FileName,'Color',[1 1 1],'NumberTitle','off', 'Visible', obj.PlotOptions.Visible);
            
            % figure state
            obj.State.Figure.Handle = fig_han;
            
            % update
            if updatekey
                obj.update;
            end
            
            % add figure listeners
            addlistener(obj.State.Figure.Handle,'Visible','PostSet',@(src,event)updateFigureVisible(obj,src,event));
            addlistener(obj.State.Figure.Handle,'Name','PostSet',@(src,event)updateFigureName(obj,src,event));
            
            % add plot options listeners
            addlistener(obj,'PlotOptions','PostSet',@(src,event)updatePlotOptions(obj,src,event));
            
            % add user data listeners
            addlistener(obj,'UserData','PostSet',@(src,event)updateUserData(obj,src,event));
        end
        
        %-------------------------USER METHODS----------------------------%
        
        %----GET OBJ.STATE.FIGURE.HANDLE ----%
        function plotlyFigureHandle = gpf(obj)
            plotlyFigureHandle = obj.State.Figure.Handle;
            set(0,'CurrentFigure', plotlyFigureHandle);
        end
        
        %----LOAD PLOTLY REFERENCE-----%
        function obj = loadplotlyref(obj) 
            if isempty(obj.PlotlyReference)
                
                % plotly reference
                plotlyref = load('plotly_reference.mat');
                
                % update the PlotlyRef property
                obj.PlotlyReference = plotlyref.pr;
            end
        end
        
        %----KEEP THE MATLAB STYLE DEFAULTS----%
        function obj = revert(obj)
      
            % set the PlotOptions.Strip property
            obj.PlotOptions.Strip = false; 
            
            % update the object
            obj.update;   
            
        end
        
        %----STRIP THE STYLE DEFAULTS----%
        function obj = strip(obj)
            
            % set the PlotOptions.Strip property
            obj.PlotOptions.Strip = true;
            
            % load plotly reference
            obj.loadplotlyref;
            
            % strip the style keys from data
            for d = 1:length(obj.data)
                obj.data{d} = obj.stripkeys(obj.data{d}, obj.data{d}.type, 'style');
            end
            
            % strip the style keys from layout
            obj.layout = obj.stripkeys(obj.layout, 'layout', 'style');
            
        end
        
        %----GET THE FIELDS OF TYPE DATA----%
        function data = getdata(obj)
            
            % load plotly reference
            obj.loadplotlyref;
            
            % initialize output
            data = cell(1,length(obj.data));
            
            % remove style / plot_info types in data
            for d = 1:length(obj.data)
                data{d} = obj.stripkeys(obj.data{d}, obj.data{d}.type, {'style','plot_info'});
            end
            
        end
        
        %----VALIDATE THE DATA/LAYOUT KEYS----%
        function validate(obj)
            
            % load plotly reference
            obj.loadplotlyref;
            
            % validate data fields
            for d = 1:length(obj.data)
                obj.stripkeys(obj.data{d}, obj.data{d}.type, {'style','plot_info'});
            end
            
            % validate layout fields
            obj.stripkeys(obj.layout, 'layout', 'style');
            
        end
        
        %----GET PLOTLY FIGURE-----%
        function obj = download(obj, file_owner, file_id)
            plotlyfig = plotlygetfile(file_owner, file_id);
            obj.data = plotlyfig.data;
            obj.layout = plotlyfig.layout;
        end
        
        %---------------------STATIC IMAGE METHODS------------------------%
        
        %----SAVE STATIC PLOTLY IMAGE-----%
        function obj = saveas(obj, filename, varargin)
            
            % strip keys
            if obj.PlotOptions.Strip
                obj.strip;
            end
            
            % handle title
            if isempty(filename)
                handleFileName(obj);
                filename = obj.PlotOptions.FileName;
            end
            
            % create image figure
            imgfig.data = obj.data;
            imgfig.layout = obj.layout;
            
            % save image
            plotlygenimage(imgfig, filename, varargin{:});
        end
        
        %----SAVE STATIC JPEG IMAGE-----%
        function obj = jpeg(obj, filename)
            if nargin > 1
                obj.saveas(filename,'jpeg');
            else
                obj.saveas(obj.PlotOptions.FileName,'jpeg');
            end
        end
        
        %----SAVE STATIC PDF IMAGE-----%
        function obj = pdf(obj, filename)
            if nargin > 1
                obj.saveas(filename,'pdf');
            else
                obj.saveas(obj.PlotOptions.FileName,'pdf');
            end
        end
        
        %----SAVE STATIC PNG IMAGE-----%
        function obj = png(obj, filename)
            if nargin > 1
                obj.saveas(filename,'png');
            else
                obj.saveas(obj.PlotOptions.FileName,'png');
            end
        end
        
        %----SAVE STATIC SVG IMAGE-----%
        function obj = svg(obj, filename)
            if nargin > 1
                obj.saveas(filename,'svg');
            else
                obj.saveas(obj.PlotOptions.FileName,'svg');
            end
        end
        
        %----ADD A CUSTOM CAPTION-----%
        function obj = add_caption(obj, caption_string, varargin)
            
            caption.text = caption_string; 
            
            % defaults
            caption.xref = 'paper';
            caption.yref = 'paper';
            caption.xanchor = 'left';
            caption.yanchor = 'top';
            caption.x = 0.1; 
            caption.y = -0.05;
            caption.showarrow = false; 
            
            % inject any custom annotation specs
            for n = 1:2:length(varargin)
                caption = setfield(caption, varargin{n}, varargin{n+1}); 
            end
            
            % adjust the bottom margin
            obj.layout.margin.b = max(obj.layout.margin.b, ...
                    obj.PlotlyDefaults.MinCaptionMargin); 
   
            % add the new caption to the figure
            obj.State.Figure.NumTexts = obj.State.Figure.NumTexts + 1;
            obj.layout.annotations{obj.State.Figure.NumTexts} = caption; 
            
            % update the figure state
            obj.State.Text(obj.State.Figure.NumTexts).Handle = NaN;
            obj.State.Text(obj.State.Figure.NumTexts).AssociatedAxis = gca;
            obj.State.Text(obj.State.Figure.NumTexts).Title = false;
            
        end
        
        
        %------------------------REST API CALL----------------------------%
        
        %----SEND PLOT REQUEST (NO UPDATE)----%
        function obj = plotly(obj)
            
            % strip keys
            if obj.PlotOptions.Strip
                obj.strip;
            end
            
            % validate keys
            validate(obj);
            
            % handle filename
            handleFileName(obj);
            
            % handle title (for feed)
            if obj.PlotOptions.CleanFeedTitle
                cleanFeedTitle(obj);
            end
                
            %args
            args.filename = obj.PlotOptions.FileName;
            args.fileopt = obj.PlotOptions.FileOpt;
            args.world_readable = obj.PlotOptions.WorldReadable;
            
            %layout
            args.layout = obj.layout;
            
            %send to plotly
            if ~obj.PlotOptions.Offline
                response = plotly(obj.data, args);
            
                %update response
                obj.url = response.url;
                obj.error = response.error;
                obj.warning = response.warning;
                obj.message = response.message;
                
                %open url in browser
                if obj.PlotOptions.OpenURL
                    web(response.url, '-browser');
                end
            else
                obj.url = plotlyoffline(obj);   
                if obj.PlotOptions.OpenURL
                    web(obj.url, '-browser');
                end
            end 
           
        end
        
        %-----------------------FIGURE CONVERSION-------------------------%
        
        %automatic figure conversion
        function obj = update(obj)
            
            % reset figure object count
            obj.State.Figure.NumAxes = 0;
            obj.State.Figure.NumPlots = 0;
            obj.State.Figure.NumLegends = 0;
            obj.State.Figure.NumColorbars = 0;
            obj.State.Figure.NumTexts = 0;
            
            % find axes of figure
            ax = findobj(obj.State.Figure.Handle,'Type','axes','-and',{'Tag','','-or','Tag','PlotMatrixBigAx','-or','Tag','PlotMatrixScatterAx','-or','Tag','AxesGraph'});
            obj.State.Figure.NumAxes = length(ax);
            
            % update number of annotations (one title per axis)
            obj.State.Figure.NumTexts = length(ax);
            
            % find children of figure axes
            for a = 1:length(ax)
                
                % reverse axes
                axrev = length(ax) - a + 1;
                
                % set axis handle field
                obj.State.Axis(a).Handle = ax(axrev);
                
                % add title
                obj.State.Text(a).Handle = get(ax(axrev),'Title');
                obj.State.Text(a).AssociatedAxis = handle(ax(axrev));
                obj.State.Text(a).Title = true;
                
                % find plots of figure
                plots = findobj(ax(axrev),'-not','Type','Text','-not','Type','axes','-depth',1,'-not','Tag','TimeZeroLine');
                
                % add baseline objects
                baselines = findobj(ax(axrev),'-property','BaseLine');
                
                for np = 1:length(plots)
                    
                    % reverse plots
                    nprev = length(plots) - np + 1;
                    
                    % update the plot fields
                    obj.State.Figure.NumPlots = obj.State.Figure.NumPlots + 1;
                    obj.State.Plot(obj.State.Figure.NumPlots).Handle = handle(plots(nprev));
                    obj.State.Plot(obj.State.Figure.NumPlots).AssociatedAxis = handle(ax(axrev));
                    obj.State.Plot(obj.State.Figure.NumPlots).Class = getGraphClass(plots(nprev));
                end
                
                % find text of figure
                texts = findobj(ax(axrev),'Type','text','-depth',1);
                
                for t = 1:length(texts)
                    obj.State.Text(obj.State.Figure.NumTexts + t).Handle = handle(texts(t));
                    obj.State.Text(obj.State.Figure.NumTexts + t).Title = false;
                    obj.State.Text(obj.State.Figure.NumTexts + t).AssociatedAxis = handle(ax(axrev));
                end
                
                % update number of annotations
                obj.State.Figure.NumTexts = obj.State.Figure.NumTexts + length(texts);
                
            end
            
            % find legends of figure
            if isHG2
                legs = findobj(obj.State.Figure.Handle,'Type','Legend');
            else
                legs = findobj(obj.State.Figure.Handle,'Type','axes','-and','Tag','legend');
            end
                
            obj.State.Figure.NumLegends = length(legs);
            
            for g = 1:length(legs)
                obj.State.Legend(g).Handle = handle(legs(g));
                
                % find associated axis
                legendAxis = findLegendAxis(obj, handle(legs(g)));
                
                % update colorbar associated axis
                obj.State.Legend(g).AssociatedAxis = legendAxis;
            end
            
            % find colorbar of figure
            if isHG2
                cols = findobj(obj.State.Figure.Handle,'Type','Colorbar');
            else
                cols = findobj(obj.State.Figure.Handle,'Type','axes','-and','Tag','Colorbar');
            end
            
            obj.State.Figure.NumColorbars = length(cols);
            
            for c = 1:length(cols)
                
                % update colorbar handle
                obj.State.Colorbar(c).Handle = handle(cols(c));
                
                % find associated axis
                colorbarAxis = findColorbarAxis(obj, handle(cols(c)));
                
                % update colorbar associated axis
                obj.State.Colorbar(c).AssociatedAxis = colorbarAxis;
                
            end
            
            %--------------------UPDATE PLOTLY FIGURE---------------------%
            
            % reset dataget(obj.State.Figure.Handle,'Children')
            obj.data = {};
            
            % reset layout
            obj.layout = struct();
            
            % update figure
            updateFigure(obj);
            
            % update axes
            for n = 1:obj.State.Figure.NumAxes
                updateAxis(obj,n);
            end
            
            % update plots
            for n = 1:obj.State.Figure.NumPlots
                updateData(obj,n);
            end
            
            % update annotations
            for n = 1:obj.State.Figure.NumTexts
                updateAnnotation(obj,n);
            end
            
            % update legends
            for n = 1:obj.State.Figure.NumLegends
                updateLegend(obj,n);
            end
            
            % update colorbars
            for n = 1:obj.State.Figure.NumColorbars
                updateColorbar(obj,n);
            end
            
        end
        
        %----------------------EXTRACT PLOTLY INDICES---------------------%
        
        %----GET CURRENT AXIS INDEX ----%
        function currentAxisIndex = getAxisIndex(obj,axishan)
            currentAxisIndex = find(arrayfun(@(x)(eq(x.Handle,axishan)),obj.State.Axis));
        end
        
        %----GET CURRENT DATA INDEX ----%
        function currentDataIndex = getDataIndex(obj,plothan)
            currentDataIndex = find(arrayfun(@(x)(eq(x.Handle,plothan)),obj.State.Plot));
        end
        
        %----GET CURRENT ANNOTATION INDEX ----%
        function currentAnnotationIndex = getAnnotationIndex(obj,annothan)
            currentAnnotationIndex = find(arrayfun(@(x)(eq(x.Handle,annothan)),obj.State.Text));
        end
        
        
        %-------------------CALLBACK FUNCTIONS--------------------------%
        
        %----UPDATE FIGURE OPTIONS----%
        function obj = updateFigureVisible(obj,src,event)
            % update PlotOptions.Visible
            obj.PlotOptions.Visible = get(obj.State.Figure.Handle,'Visible');
        end
        
        function obj = updateFigureName(obj,src,event)
            % update PlotOptions.Name
            obj.PlotOptions.FileName = get(obj.State.Figure.Handle,'Name');
        end
        
        %----UPDATE PLOT OPTIONS----%
        function obj = updatePlotOptions(obj,src,event)
            set(obj.State.Figure.Handle, 'Name', obj.PlotOptions.FileName, 'Visible', obj.PlotOptions.Visible);
        end
        
        %----UPDATE USER DATA----%
        function obj = updateUserData(obj,src,event)
            signin(obj.UserData.Username,...
                obj.UserData.ApiKey,...
                obj.UserData.PlotlyDomain);
        end
        
        %-------------------OVERLOADED FUNCTIONS--------------------------%
        
        %----PLOT FUNCTIONS----%
        function han = image(obj, varargin)
            %call image
            han = image(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = imagesc(obj, varargin)
            %call imagesc
            han = imagesc(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = line(obj, varargin)
            %call line
            han = line(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = patch(obj, varargin)
            %call patch
            han = patch(varargin{:});
            %update object
            obj.update;
        end
        
        function han = rectangle(obj, varargin)
            %call rectangle
            han = rectangle(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = area(obj,varargin)
            %call area
            han = area(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = bar(obj,varargin)
            %call bar
            han = bar(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = contour(obj,varargin)
            %call contour
            han = contour(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = plot(obj,varargin)
            %call plot
            han = plot(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = errorbar(obj,varargin)
            %call errorbar
            han = errorbar(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = quiver(obj,varargin)
            %call quiver
            han = quiver(varargin{:});
            %update object
            obj.update;
        end
        
        function han = scatter(obj, varargin)
            %call bar
            han = scatter(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = stairs(obj,varargin)
            %call stairs
            han = stairs(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = stem(obj,varargin)
            %call stem
            han = stem(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = boxplot(obj,varargin)
            %call boxplot
            han = boxplot(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function han = mesh(obj,varargin)
            %call mesh
            han = mesh(varargin{:});
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        function [y,t,x] = initial(obj,varargin)
            % plot initial
            initial(varargin{:});
            % call initial
            [y,t,x] = initial(varargin{:});
            % fake output by calling plot
            plot(t,y); 
            %update object
            obj.update;
            %send to plotly
            obj.plotly;
        end
        
        %----OTHER----%
        function delete(obj)
            % reset persistent USERNAME, KEY, and DOMAIN
            % of signin to original state
            if isfield(obj.InitialState,'Username')
                signin(obj.InitialState.Username, ...
                    obj.InitialState.ApiKey,...
                    obj.InitialState.PlotlyDomain);
            end
        end
    end
    
    methods (Access=private)
        %----STRIP THE FIELDS OF A SPECIFIED KEY-----%
        function stripped = stripkeys(obj, fields, fieldname, key)
            
            %plorlt reference
            pr = obj.PlotlyReference;
            
            % initialize output
            stripped = fields;
            
            % get fieldnames
            fn = fieldnames(stripped);
            fnmod = fn;
            
            try
                for d = 1:length(fn);
                    
                    % clean up axis keys
                    if any(strfind(fn{d},'xaxis')) || any(strfind(fn{d},'yaxis'))
                        fnmod{d} = fn{d}(1:length('_axis'));
                    end
                    
                    % keys:(object, style, plot_info, data)
                    keytype = getfield(pr,fieldname,fnmod{d},'key_type');
                    
                    % check for objects
                    if strcmp(keytype,'object')
                        
                        % clean up font keys
                        if any(strfind(fn{d},'font'))
                            fnmod{d} = 'font';
                        end
                        
                        % handle annotations
                        if strcmp(fn{d},'annotations')
                            annot = stripped.(fn{d});
                            fnmod{d} = 'annotation';
                            for a = 1:length(annot)
                                %recursive call to stripkeys
                                stripped.annotations{a} = obj.stripkeys(annot{a}, fnmod{d}, key);
                            end
                        else
                            %recursive call to stripkeys
                            stripped.(fn{d}) = obj.stripkeys(stripped.(fn{d}), fnmod{d}, key);
                        end
                        
                        % look for desired key and strip if not an exception
                    elseif any(strcmp(keytype, key))
                        if ~isExceptionStrip(stripped,fn{d})
                            stripped = rmfield(stripped, fn{d});
                        end
                    end
                    
                end
                
                %----CLEAN UP----%
                remfn = fieldnames(stripped);
                
                for n = 1:length(remfn)
                    if isstruct(stripped.(remfn{n}))
                        if isempty(fieldnames(stripped.(remfn{n})))
                            stripped = rmfield(stripped,remfn{n});
                        end
                    elseif isempty(stripped.(remfn{n}))
                        stripped = rmfield(stripped,remfn{n});
                    end
                end
                
                %---HANDLE ERRORS---%
            catch exception
                if obj.UserData.Verbose
                    % catch 3D output until integrated into graphref
                    if ~(strcmpi(fieldname,'surface') || strcmpi(fieldname,'scatter3d'))
                        fprintf(['\nWhoops! ' exception.message(1:end-1) ' in ' fieldname '\n\n']);
                    end
                end 
            end
        end

        function link_text = get_link_text(obj)
           plotly_domain = obj.UserData.PlotlyDomain; 
           link_domain = strrep(plotly_domain, 'https://', ''); 
           link_domain = strrep(link_domain, 'http://', ''); 
           link_text = ['Export to ' link_domain]; 
        end   
    end
end
