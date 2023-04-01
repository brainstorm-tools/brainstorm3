function ViewTable(Data, Description, Time, wndTitle)
    import java.awt.*;
    import javax.swing.*;
    import javax.swing.table.*;
    import org.brainstorm.icon.*;
    % Progress bar
    bst_progress('start', 'View data as table', 'Loading data...');
    % Create figure
    jFrame = java_create('javax.swing.JFrame', 'Ljava.lang.String;', wndTitle);
    % Set icon
    jFrame.setIconImage(IconLoader.ICON_APP.getImage());
    % Create cell matrix of strings to display
    if istable(Data)
        rows = table2cell(Data);
    else
        rows = reshape(cellstr(num2str(Data(:))), size(Data,1), size(Data,2));
    end
    % Define column headers 
    if (size(Description,2) == size(Data,2))
        colTitle = Description(1,:);
        firstCol = ' ';
    elseif (length(Time) == size(Data,2))
        colTitle = cellstr(num2str(Time(:)))';
        firstCol = 'Time';
    else
        colTitle = [];
    end
    % Add row descriptions
    isRowTitle = (size(Description,1) == size(Data,1));
    if isRowTitle
        rows = cat(2, Description(:,1), rows);
        if ~isempty(colTitle)
            colTitle = cat(2, firstCol, colTitle);
        end
    end
    % Create tabel model
    model = DefaultTableModel(size(rows,1), size(rows,2));
    for i = 1:size(rows)
        model.insertRow(i-1, rows(i,:));
    end
    % Create table
    jTable = JTable(model);
    jTable.setEnabled(0);
    jTable.setAutoResizeMode( JTable.AUTO_RESIZE_OFF );
    jTable.getTableHeader.setReorderingAllowed(0);
    % Set columns titles
    for iCol = 1:length(colTitle)
        % jTable.getColumnModel().getColumn(iCol-1).setPreferredWidth(50);
        jTable.getColumnModel().getColumn(iCol-1).setHeaderValue(colTitle{iCol});
    end
    % Create scroll panel
    jScroll = JScrollPane(jTable);
    jScroll.setBorder([]);
    jFrame.getContentPane.add(jScroll, BorderLayout.CENTER);
    % Show window
    jFrame.pack();
    jFrame.show();
    bst_progress('stop');
end   



