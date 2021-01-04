classdef   node < handle
    % NODE Helper class for circularGraph. Not intended for direct user manipulation.
    %%
    % Copyright 2016 The MathWorks, Inc.
    properties (Access = public)
        NodeIndex;
        Label = '';             % String
        Links = line(0,0); % Array of lines
        Position;               % [x,y] coordinates
        Color = [0.7 0.7 0.7];  % [r g b] default grey node
        LabelColor = [1 1 1]    % [r g b] default white
        Selected = true;         % Logical true or false
        isAgregatingNode = false; % if this node is a grouped node/scout /lobe
        LabelVisible = true;    % logical true or false if label is visible or not

    end
    
    properties (Access = public, Dependent = true)
        Extent; % Width of text label
    end
    
    properties (Access = private)
        TextLabel;    % Text graphics object
        NodeMarker;   % Line object that makes the node visible
        Marker = 'o'; % Marker symbol when the node is selected 'on'
        MarkerFaceColor = [0.7 0.7 0.7];
    end
    
    properties (Access = private, Constant)
        labelOffsetFactor = 1.05;
    end
    
    methods
        function this = node(x,y,index)
            % Constructor
            this.NodeIndex = index;
            this.Position = [x,y];
            this.Links = line(0,0);
            makeLine(this);
        end
        
        function makeLine(this)
            % Make the node's line graphic object
            this.NodeMarker = line(...
                this.Position(1),...
                this.Position(2),...
                -2,... #z coordinate 
                'Color',this.Color,...
                'Marker',this.Marker,...
                'MarkerFaceColor', this.Color,...
                'MarkerSize', 5,... #default (6) is too big
                'LineStyle','none',...
                'PickableParts','all',...
                'ButtonDownFcn',@node.ButtonDownFcn,...
                'UserData',this);
        end
        
        function set.Selected(this,value)
            this.Selected = value;
            updateSelected(this);
        end
        
        function set.LabelVisible(this,value)
            this.LabelVisible = value;
            updateLabelVisible(this);
        end
        
        function set.Color(this,value)
            this.Color = value;
            updateColor(this);
        end
        
        function set.Label(this,value)
            this.Label = value;
            updateTextLabel(this);
        end
        
        % don't actually need this if using the implementation from Dec 26
        function set.isAgregatingNode(this,value)
            this.isAgregatingNode = value;
            % updateAgregatingNode(this); % added Oct 25, bug?
            updateTextLabel(this);
        end
        
        function set.LabelColor(this,value)
            this.LabelColor = value;
            updateTextLabelColor(this);
        end
        
        function value = get.Extent(this)
            value = this.TextLabel.Extent(3);
        end
        
        function updateSelected(this)
            if this.Selected % node is SELECTED ("ON")
                this.NodeMarker.Marker = 'o';
                this.NodeMarker.Color = this.NodeMarker.MarkerFaceColor;
            else % node is NOT selected ("OFF") (displays as a grey X)
                this.NodeMarker.Marker = 'x'; % changed on Oct 25
                this.NodeMarker.Color =  [0.7 0.7 0.7]; % grey when "off"
            end
        end
        
        function updateLabelVisible(this)
            if (this.LabelVisible)
                this.TextLabel.Visible = 'on';
            else 
                this.TextLabel.Visible = 'off';
            end
        end
        
        function updateColor(this) % when is this called?
            this.NodeMarker.Color = this.Color;
            this.NodeMarker.MarkerFaceColor = this.Color; % set marker fill color
        end
        
        function updateTextLabelColor(this)
            set(this.TextLabel,'Color',this.LabelColor);
        end
        
        function updateTextLabel(this)
            delete(this.TextLabel);
            
            x = this.Position(1);
            y = this.Position(2);
            t = atan2(y,x);
            
            this.TextLabel = text(0,0,this.Label, 'Interpreter', 'none'); % display with '_'
            this.TextLabel.Position = node.labelOffsetFactor*this.Position;
            this.TextLabel.FontSize = this.TextLabel.FontSize-3; %default size too big
            if (this.LabelVisible)
                this.TextLabel.Visible = 'on';
            else 
                this.TextLabel.Visible = 'off';
            end
            
            %rotate and align labels
            if (~this.isAgregatingNode)
                if abs(t) > pi/2
                    this.TextLabel.Rotation = 180*(t/pi + 1);
                else
                    this.TextLabel.Rotation = t*180/pi;
                end
            end
            
            if abs(t) > pi/2
                this.TextLabel.HorizontalAlignment = 'right';
            end
        end
        
        function delete(this)
            % Destructor
            delete(this.Links(:))
            delete(this.TextLabel);
            delete(this.NodeMarker);
            delete(this);
        end
        
    end
    
    methods (Static = true)
        
        %node is to be selected/unselected by mouse click
          function ButtonDownFcn(this,~)
              % NOTE: we use functions within figure_connect's NodeClickedEvent and SetSelectedNodes 
              % to set actual node and link selection display 
              
              % all we need to do here is make sure that the correct index
              % of the clicked node is stored for access
              n = this.UserData;
              disp("Node with label '" + n.Label + "' was clicked");
              global GlobalData
              GlobalData.FigConnect.ClickedNodeIndex = n.NodeIndex;
          end
    end
end
 