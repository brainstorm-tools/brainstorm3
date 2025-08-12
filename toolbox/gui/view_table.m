function jFrame = view_table(Data, Headers, WndTitle)
% VIEW_TABLE: Display a cell array Data as table
%
% USAGE:  jFrame = view_table(Data, Headers,  wndTitle='Table')
%
% INPUT:
%     - Data     : Cell array [M,N] of char vectors
%     - Headers  : Cell array [1,M] or [M,1] of char vectors. Default = []
%     - WndTitle : Title for window displaying the table.     Default = 'Table'
%
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Raymundo Cassani, 2025

import java.awt.*;
import javax.swing.*;
import javax.swing.table.*;
import org.brainstorm.icon.*;

% Parse inputs
if nargin < 3 || isempty(WndTitle)
    WndTitle = 'Table';
end
if nargin < 2
    Headers = [];
end

% Check agreement between number of columns and number of headers
if ~isempty(Headers) && (numel(Headers) ~= size(Data, 2))
    disp(['BST> Cannot display table.' 10 ...
          'Number of columns must be the same as number of headers.'])
    return
end

% Create figure
jFrame = java_create('javax.swing.JFrame', 'Ljava.lang.String;', WndTitle);
% Set icon
jFrame.setIconImage(IconLoader.ICON_APP.getImage());
% Create tabel model
model = DefaultTableModel(size(Data,1), size(Data,2));
for i = 1:size(Data,1)
    model.insertRow(i-1, Data(i,:));
end
% Create table
jTable = JTable(model);
jTable.setEnabled(0);
jTable.setAutoResizeMode( JTable.AUTO_RESIZE_OFF );
jTable.getTableHeader.setReorderingAllowed(0);
% Set columns titles
for iHeader = 1:length(Headers)
    jTable.getColumnModel().getColumn(iHeader-1).setHeaderValue(Headers{iHeader});
end
% Create scroll panel
jScroll = JScrollPane(jTable);
jScroll.setBorder([]);
jFrame.getContentPane.add(jScroll, BorderLayout.CENTER);
% Show window
jFrame.pack();
jFrame.show();

end