void move_to_planet(int i)
{
  	// take off
	int p_x = planets[i].x, p_y = planets[i].y;
	int bot_x = bot.x, bot_y = bot.y;

	bot.x_vel = bot_x < p_x ? 10 : -10;

	while (abs(bot.x - p_x) < [MIN_PLANET_RADIUS - 3]); // spin spin

	bot.x_vel = 0;
	bot.y_vel = bot_y < p_y ? 10 : -10;

	while (abs(bot.y - p_y) < [MIN_PLANET_RADIUS - 3]);

	bot.y_vel = 0;

	while (LANDING_REQUEST == -1);
}
