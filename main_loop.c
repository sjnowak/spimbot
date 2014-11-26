// General function:
// 1. Check if there are any delivered puzzles via delivered_puzzles array
// 2. If there are, go to that planet and solve its puzzles
// 3. If not, find the nearest puzzle without a pending puzzle request and request a puzzle

// C code

// main:
int main()
{
	struct planet_info_t planets[5]; 
	int pending_requests[5];
	int delivered_puzzles[5];
	struct node puzzles[5]; // each array entry is a pointer to 8kb of reserved memory

	// main_loop:
	while (1) {
		int i = 0, j = -1;
		// main_loop_delv_check:
		while (i < 5) {
			if (delivered_puzzles[i] == 1) {
				j = i;
				break;
			}
			// main_loop_delv_inc:
			i++;
		}

		// main_delv_success_check:
		if (j >= 0) {
			move_to_planet(j);
			solve_puzzles(j);
		}
		// main_find_planet:
		else {
			i = 0;
			// main_find_planet_loop
			while (i < 5) {
				// at this point just find the first planet without a pending request for simplicity. 
				// can be later be optimized to find the closest planet without a pending request if we have time
				if (pending_requests[i] == 0) { 
					move_to_planet(i);
					// request puzzle for planets[i]
				}
				// main_find_planet_loop_inc
				i++;
			}
		}
	}

	return 0;
}
