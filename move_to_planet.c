void move_to_planet(int i)
{
  	// move_to_planet:
  	// take off
	int p_x = planets[i].x, p_y = planets[i].y, p_rad = planets[i].radius;
	int bot_x = bot.x, bot_y = bot.y;

	if (bot_x < p_x) {
		bot.angle = 0;
		bot.x_vel = 10;
	}
	// x_check_else:
	else {
		bot.angle = 180;
		bot.x_vel = -10;
	}

	// mtp_move_x_loop:
	while (abs(bot.x - p_x) > p_rad - 3); // spin spin
	// y_check:
	bot.x_vel = 0;
	
	if (bot_y < p_y) {
		bot.angle = 90;
		bot.y_vel = 10;
	}
	// y_check_else:
	else {
		bot.angle = 270;
		bot.y_vel = -10;
	}
		
	// mtp_move_y_loop:
	while (abs(bot.y - p_y) > p_rad - 3);
	// mtp_land:
	bot.y_vel = 0;

	while (LANDING_REQUEST == -1);
	// mtp_ret:
}
