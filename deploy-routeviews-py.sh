#!/bin/sh

# Quickly deploy routeviews-py to monitor BGP changes

if [ -z "$1" ]; then
	echo "Usage: ./deploy-routeviews-py.sh 123,456,789"
	echo "Installation will occur in the current directory."
	exit 0
else
	current_dir=$(pwd)
	if [ ! -f "routeviews-py.py" ]; then
		wget https://raw.githubusercontent.com/tprime-/routeviews-py/master/routeviews-py.py
		chmod +x routeviews-py.py
	fi
	
	# add to crontab
	echo "Writing the following to your crontab:\n0 0,2,4,6,8,10,12,14,16,18,20,22 * * * $current_dir/routeviews-py.py -a $1 -o $current_dir/bgp.db"
	(crontab -l ; echo "0 0,2,4,6,8,10,12,14,16,18,20,22 * * * $current_dir/routeviews-py.py -a $1 -o $current_dir/bgp.db") | crontab
	
	# create webpage
	cat <<'EOF' >> index.php
<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8">
		<title>routeviews-py output</title>
		<script src="https://code.jquery.com/jquery-3.2.1.js"></script>
		<script src="https://code.highcharts.com/highcharts.js"></script>
	</head>
	<body>
		<?php
			//warning: awful code below

		 	//connect to db
			$db = new SQLite3("bgp.db") or die("Cannot open the database.");
			$asns = $db->query("SELECT DISTINCT ASN FROM BGP_DATA;");
			$dates = $db->query("SELECT DISTINCT DATE FROM BGP_DATA;");

			//start counter
			$i = 0;
			
			//for each unique ASN...
			while ($row = $asns->fetchArray()) {
				$current_asn = $row['ASN'];
				//...select the peer count...
				$results = $db->query("SELECT COUNT FROM BGP_DATA WHERE ASN=$current_asn ORDER BY DATE ASC;");
				//...then add each count to an array, within the array
				while ($row = $results->fetchArray(SQLITE3_NUM)) { 
					$graph_data[$i][] = $row[0];
				}
				$i++;

				//add to $asn_list[] for use in the graph later
				$asn_list[] = $current_asn;
			}
		?>

		<div align="center">
			<h3>deploy-routeviews-py output</h3>
		
			<script type="text/javascript">
				$(function () {
			        $('#container').highcharts({
						chart: {
							type: 'line',
							zoomType: 'x'
						},
						title: {
							text: 'Observed paths per ASN',
							x: -20 //center
						},
						subtitle: {
							text: 'click and drag to zoom',
							x: -20
						},
						xAxis: {
							categories: [<?php while ($row = $dates->fetchArray()) { print "\"" . $row['DATE'] . "\","; } ?>]
						},
						yAxis: {
							title: {
								text: 'Observed paths per ASN'
							},
							plotLines: [{
								value: 0,
								width: 1,
								color: '#808080'
							}]
						},
						legend: {
							layout: 'vertical',
							align: 'right',
							verticalAlign: 'middle',
							borderWidth: 0
						},
						series: [
							<?php 
								foreach(array_keys($graph_data) as $key) {
									echo "{name: '" . $asn_list[$key] . "', data: [";
									foreach ($graph_data[$key] as $point){
										echo $point . ",";
									}
									echo "]},";
								}
							?>
						]
				});
			});
			</script>
			<div id="container" style="min-width: 500px; min-height: 400px; margin: 0 auto;"></div>
		</div>
	</body>
</html>
EOF

	if [ -f "index.php" ]; then
		echo "Graph has been written to index.php. Ensure that bgp.db is in the same directory when viewing."
	fi
fi