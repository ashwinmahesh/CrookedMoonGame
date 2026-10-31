"""The rooms of Wickermoor Village (R11): each story building's inside, drawn as rows, plus one small-shop shell dressed seven ways.
Every room: {key: {name, w, h, rows, door (x, y), spawn (x, y), props, ...}}. A door is the cell in the south (or named) wall."""


class G:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.c = [["#"] * w for _ in range(h)]

    def fill(self, x0, y0, x1, y1, ch="."):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.c[y][x] = ch
        return self

    def room(self, x0, y0, x1, y1):             # floor inside, walls kept
        return self.fill(x0, y0, x1, y1, ".")

    def wall(self, x0, y0, x1, y1):
        return self.fill(x0, y0, x1, y1, "#")

    def put(self, cells, ch):
        for (x, y) in cells:
            self.c[y][x] = ch
        return self

    def rows(self):
        return ["".join(r) for r in self.c]


def inn_ground():
    g = G(30, 22).room(1, 1, 28, 20)
    g.wall(10, 1, 10, 7).fill(10, 4, 10, 4, ".")          # the kitchen's west wall, a doorway
    g.wall(1, 8, 10, 8).fill(5, 8, 5, 8, ".")             # the pantry below it
    g.fill(2, 2, 8, 2, "=").fill(2, 5, 4, 5, "=")         # the kitchen's counters
    g.fill(19, 1, 28, 6, "_")                              # the little theatre's stage
    g.wall(18, 1, 18, 6).fill(18, 5, 18, 5, ".")           # its wing wall
    g.fill(12, 10, 24, 10, "=")                             # the bar
    g.put([(13, 13), (14, 13), (18, 13), (19, 13), (23, 13), (24, 13), (13, 16), (14, 16), (18, 16), (19, 16), (23, 16), (24, 16)], "=")  # tables
    g.put([(2, 13), (2, 14), (2, 15), (5, 17), (6, 17)], "=")
    g.wall(26, 8, 28, 9).fill(27, 8, 27, 8, ".")           # the stair's wall (the stair itself is the exit at 27,8)
    return dict(name="The Green Queen Inn", rows=g.rows(), door=(14, 21), spawn=(14, 19), extra_exits=[("stairs_up", (27, 8), "wickermoor_green_queen_inn_upper", "from_stairs", "Stairs up"),
                ("yard_door", (29, 15), "wickermoor_village", "from_inn_yard", "The stable yard")], npc_spots={"alda_farnum": (15, 9), "stage": (23, 4)})


def inn_upper():
    g = G(30, 14).room(1, 1, 28, 12)
    g.wall(1, 6, 28, 6)
    for x in (7, 13, 19, 25):
        g.fill(x, 6, x, 6, ".")                               # doors into the rooms
    for x in (6, 12, 18, 24):
        g.wall(x, 1, x, 5)                                    # partitions between the northern rooms
    g.put([(2, 2), (3, 2), (8, 2), (9, 2), (14, 2), (15, 2), (20, 2), (21, 2), (26, 2), (27, 2)], "=")   # beds
    g.put([(2, 9), (3, 9), (9, 9), (10, 9), (20, 9), (21, 9), (22, 9)], "=")                                # beds, the suite's
    g.wall(15, 7, 15, 12).fill(15, 10, 15, 10, ".")
    return dict(name="The Green Queen Inn, upstairs", rows=g.rows(), door=(1, 13), spawn=(2, 7), exits_to=("stairs_down", (2, 13), "wickermoor_green_queen_inn", "from_stairs"))


def mayor():
    g = G(28, 22).room(1, 1, 26, 20)
    g.wall(1, 12, 26, 12).fill(13, 12, 14, 12, ".")       # the records office below, the private home above
    g.wall(14, 13, 14, 19).fill(14, 16, 14, 16, ".")
    g.fill(3, 14, 10, 14, "=").fill(3, 18, 8, 18, "=")     # counters and filing
    g.fill(16, 14, 24, 16, ".").put([(17, 15), (18, 15), (22, 15), (23, 15)], "=")
    g.fill(3, 3, 12, 3, "=").put([(5, 7), (6, 7), (9, 7), (10, 7)], "=")        # the dining table's end, chairs
    g.put([(18, 3), (19, 3), (20, 3), (21, 3)], "=")
    g.wall(22, 7, 26, 7).fill(24, 7, 24, 7, ".")         # the stair to the clock chamber
    return dict(name="The Mayor's House", rows=g.rows(), door=(13, 21), spawn=(13, 19), extra_exits=[("clock_stair", (24, 8), "wickermoor_clock_chamber", "from_stair", "The clocktower stair")])


def clock_chamber():
    g = G(12, 12).room(1, 1, 10, 10)
    g.put([(5, 5), (6, 5), (5, 6), (6, 6)], "=")           # the works
    g.wall(1, 8, 4, 8)
    return dict(name="The Clock Chamber", rows=g.rows(), door=(5, 11), spawn=(5, 9), door_to=("wickermoor_mayors_house", "from_clock", "Down the stair"))


def constable():
    g = G(20, 16).room(1, 1, 18, 14)
    g.wall(1, 9, 8, 9).wall(11, 9, 18, 9)                   # the office below, the cells above, a way through in the middle
    g.wall(6, 1, 6, 6).wall(12, 1, 12, 6)                   # the cells' partitions: three cells open on the walk in front of them
    g.fill(2, 12, 7, 12, "=").fill(13, 12, 17, 12, "=").put([(12, 11), (13, 11)], "=")   # desks and the filing
    return dict(name="The Constable's Station", rows=g.rows(), door=(9, 15), spawn=(9, 13))


def trading():
    g = G(22, 16).room(1, 1, 20, 14)
    g.wall(1, 8, 20, 8).fill(10, 8, 11, 8, ".")           # the showroom below the stockroom
    g.fill(3, 11, 10, 11, "=").fill(14, 11, 18, 11, "=").put([(4, 3), (5, 3), (9, 3), (10, 3), (14, 3), (15, 3)], "=")
    g.fill(3, 5, 8, 5, "=").put([(17, 5), (18, 5), (17, 6), (18, 6)], "=")
    return dict(name="Tolliver's Trading Post", rows=g.rows(), door=(10, 15), spawn=(10, 13), extra_exits=[("cellar", (19, 2), "wickermoor_town_cellars", "from_trading", "The stair down")])


def apothecary():
    g = G(16, 14).room(1, 1, 14, 12)
    g.wall(1, 6, 14, 6).fill(7, 6, 8, 6, ".")
    g.fill(2, 9, 6, 9, "=").fill(9, 9, 13, 9, "=").fill(2, 2, 6, 2, "=").fill(9, 2, 13, 3, "=").put([(12, 4), (13, 4)], "=")
    return dict(name="The Apothecary", rows=g.rows(), door=(7, 13), spawn=(7, 11))


def barber():
    g = G(14, 12).room(1, 1, 12, 10)
    g.put([(3, 3), (4, 3), (8, 3), (9, 3)], "=").fill(2, 7, 11, 7, "=").fill(7, 7, 7, 7, ".").put([(11, 2), (11, 3)], "=")
    g.wall(1, 5, 5, 5).fill(5, 5, 5, 5, ".")
    return dict(name="Graham's Barber Shop", rows=g.rows(), door=(6, 11), spawn=(6, 9), secret_door=(12, 6))


def school():
    g = G(16, 12).room(1, 1, 14, 10)
    for y in (3, 5, 7):
        g.fill(3, y, 6, y, "=").fill(9, y, 12, y, "=")
    g.fill(6, 1, 9, 1, "=")
    return dict(name="The Schoolhouse", rows=g.rows(), door=(7, 11), spawn=(7, 9))


def post():
    g = G(16, 14).room(1, 1, 14, 12)
    g.fill(2, 4, 12, 4, "=").put([(3, 8), (4, 8), (5, 8), (9, 8), (10, 8), (11, 8)], "=").fill(2, 1, 13, 1, "=")
    g.wall(1, 6, 3, 6)
    return dict(name="The Post Office", rows=g.rows(), door=(7, 13), spawn=(7, 11), extra_exits=[("dovecote_stair", (14, 1), "wickermoor_dovecote", "from_post", "The dovecote path")])


def dovecote():
    g = G(12, 12).room(2, 2, 9, 9)
    g.put([(3, 3), (4, 3), (7, 3), (8, 3), (3, 8), (8, 8)], "=").put([(5, 5), (6, 6)], "=")
    g.wall(2, 2, 2, 2).wall(9, 2, 9, 2).wall(2, 9, 2, 9).wall(9, 9, 9, 9)
    return dict(name="The Dovecote", rows=g.rows(), door=(5, 10), spawn=(5, 8))


def funeral():
    g = G(20, 16).room(1, 1, 18, 14)
    g.wall(1, 8, 18, 8).fill(9, 8, 10, 8, ".")
    g.fill(4, 2, 9, 2, "=").fill(12, 2, 16, 2, "=").put([(3, 5), (4, 5), (15, 5), (16, 5)], "=")
    g.fill(3, 11, 7, 11, "=").fill(12, 11, 16, 11, "=")
    return dict(name="Shade Funeral Home", rows=g.rows(), door=(9, 15), spawn=(9, 13))


def books():
    g = G(14, 14).room(1, 1, 12, 12)
    g.wall(1, 7, 12, 7).fill(6, 7, 7, 7, ".")
    g.fill(2, 2, 5, 2, "=").fill(8, 2, 11, 2, "=").fill(2, 4, 5, 4, "=").fill(8, 4, 11, 4, "=").fill(3, 9, 5, 9, "=").fill(8, 9, 10, 9, "=")
    return dict(name="The Antique Bookstore", rows=g.rows(), door=(6, 13), spawn=(6, 11))


def small_shop():
    g = G(14, 12).room(1, 1, 12, 10)
    g.fill(2, 3, 11, 3, "=").put([(2, 7), (3, 7), (9, 7), (10, 7)], "=").put([(11, 5), (11, 6)], "=")
    return dict(name="A Shop", rows=g.rows(), door=(6, 11), spawn=(6, 9))


ROOMS = {
    "wickermoor_green_queen_inn": inn_ground, "wickermoor_green_queen_inn_upper": inn_upper, "wickermoor_mayors_house": mayor,
    "wickermoor_clock_chamber": clock_chamber, "wickermoor_constable_station": constable, "wickermoor_trading_post": trading,
    "wickermoor_apothecary": apothecary, "wickermoor_barber_shop": barber, "wickermoor_schoolhouse": school, "wickermoor_post_office": post,
    "wickermoor_dovecote": dovecote, "wickermoor_funeral_home": funeral, "wickermoor_bookstore": books,
}
